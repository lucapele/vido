//------------------------------------------------------------------------------
//  Copyright (c) 2011 the original author or authors. All Rights Reserved. 
// 
//  NOTICE: You are permitted you to use, modify, and distribute this file 
//  in accordance with the terms of the license agreement accompanying it. 
//------------------------------------------------------------------------------

package org.robotlegs.v2.context.impl
{
	import flash.display.DisplayObjectContainer;
	import flash.errors.IllegalOperationError;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import org.as3commons.logging.api.ILogger;
	import org.as3commons.logging.api.getLogger;
	import org.robotlegs.core.IInjector;
	import org.robotlegs.v2.context.api.ContextBuilderEvent;
	import org.robotlegs.v2.context.api.IContext;
	import org.robotlegs.v2.context.api.IContextBuilder;
	import org.robotlegs.v2.context.api.IContextBuilderBundle;
	import org.robotlegs.v2.context.api.IContextProcessor;

	[Event(name="contextBuildComplete", type="org.robotlegs.v2.context.api.ContextBuilderEvent")]
	public class ContextBuilder extends EventDispatcher implements IContextBuilder
	{

		/*============================================================================*/
		/* Protected Static Properties                                                */
		/*============================================================================*/

		protected static const logger:ILogger = getLogger(ContextBuilder);


		/*============================================================================*/
		/* Protected Properties                                                       */
		/*============================================================================*/

		protected var buildLocked:Boolean;

		protected const configClasses:Vector.<Class> = new Vector.<Class>;

		protected const context:IContext = new Context();

		protected const processors:Vector.<IContextProcessor> = new Vector.<IContextProcessor>;

		protected const utilityConfigs:Vector.<UtilityConfig> = new Vector.<UtilityConfig>;

		/*============================================================================*/
		/* Constructor                                                                */
		/*============================================================================*/

		public function ContextBuilder()
		{
			// -- hello, welcome to Robotlegs -- //
		}


		/*============================================================================*/
		/* Public Functions                                                           */
		/*============================================================================*/

		public function addConfig(configClass:Class):IContextBuilder
		{
			logger.info('adding config: {0}', [configClass]);
			buildLocked && throwBuildLockedError();
			configClasses.push(configClass);
			return this;
		}

		public function addProcessor(processor:IContextProcessor):IContextBuilder
		{
			logger.info('adding processor: {0}', [processor]);
			buildLocked && throwBuildLockedError();
			processors.push(processor);
			return this;
		}

		/**
		 * This is horrible, but we need a way to configure dependencies before the injector has been set
		 */
		public function addUtility(type:Class, implementation:Class = null, asSingleton:Boolean = true, named:String = ''):IContextBuilder
		{
			logger.info('adding utility: {0} {1}', [type, named]);
			buildLocked && throwBuildLockedError();
			const config:UtilityConfig = new UtilityConfig(type, implementation, asSingleton, named);
			utilityConfigs.push(config);
			return this;
		}

		public function build():IContext
		{
			logger.info('starting build');
			buildLocked && throwBuildLockedError();
			buildLocked = true;
			runProcessors();
			return context;
		}

		public function installBundle(bundle:IContextBuilderBundle):IContextBuilder
		{
			logger.info('installing bundle: {0}', [bundle]);
			buildLocked && throwBuildLockedError();
			bundle.install(this);
			return this;
		}

		public function withContextView(value:DisplayObjectContainer):IContextBuilder
		{
			context.contextView = value;
			return this;
		}

		public function withDispatcher(value:IEventDispatcher):IContextBuilder
		{
			context.dispatcher = value;
			return this;
		}

		public function withInjector(value:IInjector):IContextBuilder
		{
			context.injector = value;
			return this;
		}

		public function withParent(value:IContext):IContextBuilder
		{
			context.parent = value;
			return this;
		}

		/*============================================================================*/
		/* Protected Functions                                                        */
		/*============================================================================*/

		protected function configureUtilities():void
		{
			logger.info('configuring utilities');
			utilityConfigs.forEach(function(config:UtilityConfig, ... rest):void
			{
				if (config.asSingleton)
				{
					context.injector.mapSingletonOf(config.type, config.implementation, config.name);
				}
				else
				{
					context.injector.mapClass(config.type, config.implementation, config.name);
				}
			}, this);
		}

		protected function createConfigs():void
		{
			logger.info('creating configs');
			configClasses.forEach(function(configClass:Class, ... rest):void
			{
				context.injector.instantiate(configClass);
			}, this);
		}

		protected function createUtilities():void
		{
			logger.info('creating utilities');
			utilityConfigs.forEach(function(config:UtilityConfig, ... rest):void
			{
				if (config.asSingleton)
				{
					context.injector.getInstance(config.type, config.name);
				}
			}, this);
		}

		protected function finishBuild():void
		{
			context.initialize();
			configureUtilities();
			createUtilities();
			createConfigs();
			dispatchEvent(new ContextBuilderEvent(ContextBuilderEvent.CONTEXT_BUILD_COMPLETE, this, context));
		}

		protected function processorCallback(error:Object = null):void
		{
			if (error)
			{
				throw new Error(error);
			}
			else if (processors.length > 0)
			{
				const processor:IContextProcessor = processors.shift();
				logger.info('executing processor: {0}', [processor]);
				processor.process(context, processorCallback);
			}
			else
			{
				finishBuild();
			}
		}

		protected function runProcessors():void
		{
			logger.info('running processors');
			processorCallback();
		}

		protected function throwBuildLockedError():void
		{
			const message:String = 'The build has started and is now locked';
			logger.fatal(message);
			throw new IllegalOperationError(message);
		}
	}
}

class UtilityConfig
{

	/*============================================================================*/
	/* Public Properties                                                          */
	/*============================================================================*/

	public var asSingleton:Boolean;

	public var implementation:Class;

	public var name:String;

	public var type:Class;

	/*============================================================================*/
	/* Constructor                                                                */
	/*============================================================================*/

	public function UtilityConfig(type:Class, implementation:Class, asSingleton:Boolean, named:String)
	{
		this.type = type;
		this.implementation = implementation || type;
		this.asSingleton = asSingleton;
		this.name = named;
	}
}
