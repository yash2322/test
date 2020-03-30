//
//  ToasterRunTest.m
//  ToasterRunTest
//
//  Created by Robert Woldberg on 7/25/19.
//  Copyright © 2019-2020 Sling TV. All rights reserved.
//
#import <XCTest/XCTest.h>
#include "foundation/objects/debugging/MObjectCounts.h"
#include "foundation/objects/MFile.h"
#include "Appliance/Toaster.h"
#include <iostream>

std::string configDir;
std::string testFile;

@interface SetupTests : NSObject<XCTestObservation>
@end

SetupTests* setupTestsInstance = nil;

@implementation SetupTests

-(instancetype)init
{
    if (self = [super init])
    {
        // Initialize self
        [[XCTestObservationCenter sharedTestObservationCenter] addTestObserver:self];
    }
    return self;
}

#define TO_STR(a) #a

- (void)testBundleWillStart:(NSBundle *)__unused testBundle
{
    NSDictionary* environment;

#if defined(TOASTER_PROJECT_DIR)
    configDir = TOASTER_PROJECT_DIR;
#endif
    // Look for the config dir environment variable.
    environment = [[NSProcessInfo processInfo] environment];
    for ( NSString *key in environment )
    {
        if ( [key isEqual: @"TOASTER_CONFIG_DIR"] )
        {
            configDir = [[environment valueForKey:key] UTF8String];
        }
    }
    // Use any command line params
    NSArray *arguments = [[NSProcessInfo processInfo] arguments];
    int argc = (int)[arguments count];
    for ( int index = 0; index < argc; index++)
    {
        id arg = [arguments objectAtIndex:index];
        if ( [arg isEqualToString:@"--test"] == true )
        {
            id nextArg = [arguments objectAtIndex:++index];
            testFile = [nextArg UTF8String];
        }
        else if ( [arg isEqualToString:@"--configDir"] == true )
        {
            id nextArg = [arguments objectAtIndex:++index];
            configDir = [nextArg UTF8String];
        }
        else if ( [arg isEqualToString:@"--redirectSTDOUT"] == true )
        {
            NSString *bundlePath = [[NSBundle bundleForClass:[SetupTests class]] bundlePath];
            NSMutableString* outputPath = [[NSMutableString alloc] init];
            [outputPath appendString:bundlePath];
            uint32_t location = static_cast<uint32_t>([outputPath rangeOfString:@"/" options:NSBackwardsSearch].location) + 1;
            uint32_t length = static_cast<uint32_t>([outputPath length]);
            length -= location;
            [outputPath deleteCharactersInRange:NSMakeRange( location, length )];
            [outputPath appendString:@"toasteroutput.txt"];
            freopen([outputPath UTF8String], "w+", stdout );
        }
    }

    std::cout << "Running Toaster! " << "Config Dir = '" << configDir.c_str() << "' TestFile = '" << testFile.c_str() << "'\n";    }

+ (void)load
{
    setupTestsInstance = [[SetupTests alloc] init];
}

@end

@interface ToasterRunTest : XCTestCase
@end

@implementation ToasterRunTest

- (void)setUp
{
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

-(bool)verifyNoLeaks
{
    bool result = true;

    // Make sure there were no leaks.
    const char* output[[maybe_unused]] = csl_player::MObjectCounts::instance()->getSnapShotString();
    if ( csl_player::MObjectCounts::instance()->getLastCount() > 0 )
    {
#if !defined(STRESS_TEST)
        fprintf(stdout,"Leaks Detected!\n");
        fprintf(stdout,"%s",output );
#endif
        result = false;
    }
    // Free the object counts.
    csl_player::MObjectCounts::instance(true);

    return result;
}

-(void)executeToasterTest:(const char*) testName
{
    // Change testTimes to something other than 1 for stress testing the tests.  This can be used to find timing issues in the tests.
    int x;
#if !defined(STRESS_TEST)
    constexpr int testTimes = 1;
#else
    constexpr int testTimes = 1000;
#endif
    for ( x = 0; x < testTimes; x++ )
    {
        [self doExecuteToasterTest: testName];
        if ( x % 100 == 99 )
        {
            fprintf(stdout,".");
        }
    }
    if ( x > 99 )
    {
        fprintf(stdout,"\n");
    }
}

-(void)doExecuteToasterTest:(const char*) testName
{
    csl_player::MFileSystem* fileSystem;
    csl_player::MString* fullPath = new csl_player::MString();

    // Ignore file not found errors?
    *fullPath = configDir.c_str();
    if( fullPath->findLast("/") != fullPath->length() - 1 )
    {
        fullPath->append("/");
    }

    fullPath->append( testName );

    if( fullPath->findLast( ".json" ) == csl_player::MStringNotFound )
    {
        fullPath->append( ".json" );
    }

    fileSystem = new csl_player::MFileSystem();
    if( fileSystem->exists( *fullPath ) == false )
    {
#if !defined(STRESS_TEST)
        fprintf(stdout,"Test not found: %s\n", fullPath->c_str());
#endif
        testName = nullptr;
    }
    delete fileSystem;
    delete fullPath;
    fullPath = nullptr;

    if( testName != nullptr && strlen(testName) > 0 )
    {
        Appliance::SToaster toaster = std::make_shared<Appliance::Toaster>();
        toaster->setConfigDir ( configDir.c_str() );
        bool testResult = toaster->execute ( testName );
        toaster = nullptr;
        XCTAssertTrue(testResult);
        XCTAssertTrue(self.verifyNoLeaks);
    }
    else
    {
        XCTAssertTrue(false);
    }
}

- (void)testPassedTestFile
{
    if ( testFile.length() != 0 )
    {
        [self executeToasterTest: testFile.c_str()];
    }
    else
    {
        XCTAssertTrue(true);
    }
}

- (void)testPrebuffer
{
    [self executeToasterTest: "testPrebuffer"];
}

- (void)testPrebufferWhilePlayingSame
{
    [self executeToasterTest: "testPrebufferWhilePlayingSame"];
}

- (void)testPrebufferWhilePlayingDifferent
{
    [self executeToasterTest: "testPrebufferWhilePlayingDifferent"];
}

- (void)testPrebufferTwoContentsPlayFirst
{
    [self executeToasterTest: "testPrebufferTwoContentsPlayFirst"];
}

- (void)testMultiplePrebufferSameQvt
{
    [self executeToasterTest: "testMultiplePrebufferSameQvt"];
}

- (void)testUnload
{
    [self executeToasterTest: "testUnload"];
}

- (void)testSimplePlay
{
    [self executeToasterTest: "testSimplePlay"];
}

- (void)testPlayMultipleStages
{
    [self executeToasterTest: "testPlayMultipleStages"];
}

- (void)testPlayAtPosition
{
    [self executeToasterTest: "testPlayAtPosition"];
}

- (void)testPlayAtInvalidPosition
{
    [self executeToasterTest: "testPlayAtInvalidPosition"];
}

- (void)testPause
{
    [self executeToasterTest: "testPause"];
}

- (void)testSeek
{
    [self executeToasterTest: "testSeek"];
}

- (void)testSeekBackwards
{
    [self executeToasterTest: "testSeekBackwards"];
}

- (void)testSeekJIT
{
    [self executeToasterTest: "testSeekJIT"];
}

- (void)testResume
{
    [self executeToasterTest: "testResume"];
}

- (void)testBitrateChanged
{
    [self executeToasterTest: "testBitrateChanged"];
}

- (void)testChangeBitrate
{
    [self executeToasterTest: "testChangeBitrate"];
}

- (void)testLimitBitrate
{
    [self executeToasterTest: "testLimitBitrate"];
}

- (void)testMute
{
    [self executeToasterTest: "testMute"];
}

- (void)testMediaTrack
{
    [self executeToasterTest: "testMediaTrack"];
}

- (void)testNetworkError
{
    [self executeToasterTest: "testNetworkError"];
}

- (void)testGetCurrentState
{
    [self executeToasterTest: "testGetCurrentState"];
}

- (void)testPlayerState
{
    [self executeToasterTest: "testPlayerState"];
}

- (void)testPlayVODAtLivePosition
{
    [self executeToasterTest: "testPlayVODAtLivePosition"];
}

// This test is not correct so I am turning it off, a ticked should be created to update the test with what we think the expects should be then update the code.
//- (void)testDAI
//{
//    [self executeToasterTest: "testDAI"];
//}

- (void)testSetPlayerError
{
    [self executeToasterTest: "testSetPlayerError"];
}

- (void)testPlayerRetry
{
    [self executeToasterTest: "testPlayerRetry"];
}

-(void)testPrebufferTwoContentsPlaySecond
{
    [self executeToasterTest:"testPrebufferTwoContentsPlaySecond"];
}

-(void)testSimplePlayCompleteDVR
{
    [self executeToasterTest: "testSimplePlayCompleteDVR"];
}

-(void)testLongPlayFastClock
{
    [self executeToasterTest:"testLongPlayFastClock"];
}

-(void)testChangeCDN
{
    [self executeToasterTest: "testChangeCDN"];
}

 -(void)testID3Tag
{
    [self executeToasterTest: "testID3Tag"];
}

-(void)testPrebufferAndPlayLocalNow
{
    [self executeToasterTest: "testPrebufferAndPlayLocalNow"];
}

-(void)testHttpDownloadErrorLocalNow
{
    [self executeToasterTest: "testHttpDownloadErrorLocalNow"];
}

-(void)testJsonParsingErrorLocalNow
{
    [self executeToasterTest: "testJsonParsingErrorLocalNow"];
}

-(void)testManifestUrlNotFoundErrorLocalNow
{
    [self executeToasterTest: "testManifestUrlNotFoundErrorLocalNow"];
}

-(void)testEmptyJsonResponseLocalNow
{
    [self executeToasterTest: "testEmptyJsonResponseLocalNow"];
}

-(void)testWeatherSessionPingError
{
    [self executeToasterTest: "testWeatherSessionPingError"];
}

-(void)testPrebufferAndPlayESPN3PCC
{
    [self executeToasterTest: "testPrebufferAndPlayESPN3PCC"];
}

-(void)testESPN3PCCHttpDownloadError
{
    [self executeToasterTest: "testESPN3PCCHttpDownloadError"];
}

-(void)testESPN3PCCJsonParsingError
{
    [self executeToasterTest: "testESPN3PCCJsonParsingError"];
}

-(void)testESPN3PCCStreamError
{
    [self executeToasterTest: "testESPN3PCCStreamError"];
}

-(void)testPrebufferAndPlaySonyLiv
{
    [self executeToasterTest: "testPrebufferAndPlaySonyLiv"];
}

-(void)testHttpDownloadErrorSonyLiv
{
    [self executeToasterTest: "testHttpDownloadErrorSonyLiv"];
}

-(void)testJsonParsingErrorSonyLiv
{
    [self executeToasterTest: "testJsonParsingErrorSonyLiv"];
}

-(void)testManifestUrlNotFoundErrorSonyLiv
{
    [self executeToasterTest: "testManifestUrlNotFoundErrorSonyLiv"];
}

- (void)testVODRetryAfterOneFailure
{
    [self executeToasterTest: "testVODRetryAfterOneFailure"];
}

- (void)testVODRetryAfterTwoFails
{
    [self executeToasterTest: "testVODRetryAfterTwoFails"];
}

- (void)testVODRetryAfterThreeFails
{
    [self executeToasterTest: "testVODRetryAfterThreeFails"];
}

-(void)testPrebufferAndPlayLiveInternalMaiTaiChannel
{
    [self executeToasterTest: "testPrebufferAndPlayLiveInternalMaiTaiChannel"];
}

- (void)testQvtParsingError
{
    [self executeToasterTest: "testQvtParsingError"];
}

-(void)testAppendClipList
{
    [self executeToasterTest: "testAppendClipList"];
}

- (void)testQvtDownloadFailure
{
    [self executeToasterTest: "testQvtDownloadFailure"];
}

-(void)testPrebufferQvtDownloadFailure
{
    [self executeToasterTest: "testPrebufferQvtDownloadFailure"];
}

-(void)testPlayAtAd
{
    [self executeToasterTest: "testPlayAtAd"];
}

- (void)testSimplePlayInProgressDVR
{
    [self executeToasterTest: "testSimplePlayInProgressDVR"];
}


- (void)testAssetTransitionsWithTwoMinutesRemaining
{
    [self executeToasterTest: "testAssetTransitionsWithTwoMinutesRemaining"];
}

- (void)testThumbnailTVODTrailer
{
    [self executeToasterTest: "testThumbnailTVODTrailer"];
}

- (void)testThumbnailTVODTrailerError
{
    [self executeToasterTest: "testThumbnailTVODTrailerError"];
}

- (void)testSwitchDvrToLocalNow
{
    [self executeToasterTest: "testSwitchDvrToLocalNow"];
}

- (void)testSwitchSvodToLocalNow
{
    [self executeToasterTest: "testSwitchSvodToLocalNow"];
}

- (void)testMaiTaiHeadersEmptyError
{
     /** @todo AP-14894   - need to handle UMS failover. */
    //[self executeToasterTest: "testMaiTaiHeadersEmptyError"];
}

- (void)testMaiTaiInitConflictError
{
    [self executeToasterTest: "testMaiTaiInitConflictError"];
}

- (void)testMaiTaiLocationError
{
     /** @todo AP-14894   - need to handle UMS failover. */
    //[self executeToasterTest: "testMaiTaiLocationError"];
}

- (void)testMaiTaiHeartbeatConflictError
{
    [self executeToasterTest: "testMaiTaiHeartbeatConflictError"];
}

- (void)testChannelChangeWithoutStopCall
{
    [self executeToasterTest: "testChannelChangeWithoutStopCall"];
}

- (void)test3rdPartyChannelChangeWithoutStopCall
{
    [self executeToasterTest: "test3rdPartyChannelChangeWithoutStopCall"];
}

- (void)testChannelChangeWithPause
{
    [self executeToasterTest: "testChannelChangeWithPause"];
}

- (void)testChannelChangeWithStop
{
    [self executeToasterTest: "testChannelChangeWithStop"];
}

- (void)testGetPlaybackPosition
{
    [self executeToasterTest: "testGetPlaybackPosition"];
}

- (void)testPlaybackOperationsTimeshifted
{
    [self executeToasterTest: "testPlaybackOperationsTimeshifted"];
}

- (void)testSeekAfterPause
{
    [self executeToasterTest: "testSeekAfterPause"];
}

- (void)testResumeAfterPlayAndStop
{
    [self executeToasterTest: "testResumeAfterPlayAndStop"];
}

-(void)testDeviceBlackout
{
    [self executeToasterTest: "testDeviceBlackout"];
}

-(void)testBillingBlackout
{
    [self executeToasterTest: "testBillingBlackout"];
}

-(void)testBillingZipCodeBlackoutAssetTransition
{
    [self executeToasterTest: "testBillingZipCodeBlackoutAssetTransition"];
}

-(void)testDeviceZipCodeBlackoutAssetTransition
{
    [self executeToasterTest: "testDeviceZipCodeBlackoutAssetTransition"];
}

-(void)testLongPlayWithAdsFastClock
{
    [self executeToasterTest:"testLongPlayWithAdsFastClock"];
}

-(void)testPrerollMidrollSvodDai
{
    [self executeToasterTest: "testPrerollMidrollSvodDai"];
}

- (void)testThumbnailTVODTrailerWithSeek
{
    [self executeToasterTest: "testThumbnailTVODTrailerWithSeek"];
}

-(void)testCBPforPrerollandMidrollAd
{
    [self executeToasterTest:"testCBPforPrerollandMidrollAd"];
}

- (void)testPostRollClipTransitionFromContent
{
    [self executeToasterTest: "testPostRollClipTransitionFromContent"];
}
- (void)testLinearPlaybackAtMiddleOfAdbreak

{
    [self executeToasterTest: "testLinearPlaybackAtMiddleOfAdbreak"];
}

- (void)testMultiBlackoutQVT

{
    [self executeToasterTest: "testMultiBlackoutQVT"];
}

@end
