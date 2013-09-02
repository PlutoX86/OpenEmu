//
//  OEThreadGameCoreManager.m
//  OpenEmu
//
//  Created by Remy Demarest on 21/07/2013.
//
//

#import "OEThreadGameCoreManager.h"
#import "OEThreadProxy.h"
#import "OpenEmuHelperApp.h"
#import "OEGameCoreManager_Internal.h"
#import "OECorePlugin.h"

@implementation OEThreadGameCoreManager
{
    NSThread         *_helperThread;
    NSTimer          *_dummyTimer;

    OEThreadProxy    *_helperProxy;
    OpenEmuHelperApp *_helper;

    OEThreadProxy    *_displayHelperProxy;
    OEThreadProxy    *_systemClientProxy;
    id                _systemClient;

    void(^_completionHandler)(id systemClient, NSError *error);
}

- (void)loadROMWithCompletionHandler:(void(^)(id systemClient, NSError *error))completionHandler;
{
    _completionHandler = [completionHandler copy];

    _helperThread = [[NSThread alloc] initWithTarget:self selector:@selector(_executionThread:) object:nil];

    _helper = [[OpenEmuHelperApp alloc] init];
    _helperProxy = [OEThreadProxy threadProxyWithTarget:_helper thread:_helperThread];

    _displayHelperProxy = [OEThreadProxy threadProxyWithTarget:[self displayHelper] thread:[NSThread mainThread]];

    [_helperThread start];
}

- (void)dummyTimer:(NSTimer *)dummyTimer
{
    
}

- (void)_executionThread:(id)object
{
    @autoreleasepool
    {
        [self setGameCoreHelper:(id<OEGameCoreHelper>)_helperProxy];
        [_helper setDisplayHelper:(id<OEGameCoreDisplayHelper>)_displayHelperProxy];
        if(![_helper loadROMAtPath:[self ROMPath] withCorePluginAtPath:[[self plugin] path] systemIdentifier:[[self systemController] systemIdentifier]])
        {
            FIXME("Return a proper error object here.");
            _completionHandler(nil, nil);
            return;
        }

        _systemClient = [_helper gameCore];
        _systemClientProxy = [OEThreadProxy threadProxyWithTarget:_systemClient thread:_helperThread];

        dispatch_async(dispatch_get_main_queue(), ^{
            _completionHandler(_systemClientProxy, nil);
        });

        _dummyTimer = [NSTimer scheduledTimerWithTimeInterval:1e9 target:self selector:@selector(dummyTimer:) userInfo:nil repeats:YES];

        CFRunLoopRun();
    }
}

- (void)_stopHelperThread:(id)object
{
    [_helper stopEmulation];
    [_dummyTimer invalidate];
    _dummyTimer = nil;

    CFRunLoopStop(CFRunLoopGetCurrent());

    _helperThread       = nil;
    _helperProxy        = nil;
    _helper             = nil;
    _displayHelperProxy = nil;
    _systemClientProxy  = nil;
    _systemClient       = nil;
}

- (void)stop
{
    if([NSThread currentThread] == _helperThread)
        [self _stopHelperThread:nil];
    else
        [self performSelector:@selector(_stopHelperThread:) onThread:_helperThread withObject:nil waitUntilDone:YES];
}

@end
