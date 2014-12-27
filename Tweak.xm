#import <AssetsLibrary/AssetsLibrary.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>
#import <UIKit/UIKit.h>
#include <notify.h>
#import "BUIAlertView.h"

@interface NSDistributedNotificationCenter : NSNotificationCenter
+(id)defaultCenter;
-(void)postNotificationName:(id)arg1 object:(id)arg2 userInfo:(id)arg3 deliverImmediately:(BOOL)arg4 ;
-(void)addObserver:(id)arg1 selector:(SEL)arg2 name:(id)arg3 object:(id)arg4 ;
-(void)postNotificationName:(id)arg1 object:(id)arg2 userInfo:(id)arg3 ;
@end

@interface SBLaunchAppListener : NSObject
-(void)invalidate;
-(id)initWithBundleIdentifier:(id)arg1 handlerBlock:(/*^block*/id)arg2 ;
@end

@interface SBApplication : NSObject
-(BOOL)isRunning;
@end

@interface SBApplicationController : NSObject
+(id)sharedInstance;
-(SBApplication *)applicationWithBundleIdentifier:(id)b;
@end


@interface IMMessageItem : NSObject
@property (nonatomic,readonly) BOOL isRead;
@property (nonatomic,readonly) BOOL isFinished;
@property (nonatomic,readonly) BOOL isEmpty;
@property (nonatomic,retain) NSArray * fileTransferGUIDs;
@end

@interface FZMessage : IMMessageItem
@end

@interface IMFileTransfer : NSObject
@property (nonatomic,readonly) BOOL isFinished;
@property (assign,nonatomic) BOOL isIncoming; 
@property (nonatomic,retain) NSString * localPath;
@property (nonatomic,retain) NSString * type;
@property (nonatomic,retain) NSString * filename;
@property (nonatomic,retain) NSURL * localURL;
@property (assign,nonatomic) unsigned long long totalBytes;
@property (nonatomic,retain,readonly) NSString * mimeType;
@end

@interface IMFileTransferCenter : NSObject
+(id)sharedInstance;
-(IMFileTransfer *)transferForGUID:(NSString *)guid;
@end

@interface MSGAutoSaveSettings : NSObject
@property (nonatomic,readonly,getter=isEnabled) BOOL enabled;
@property (nonatomic,readonly,getter=shouldConfirmSave) BOOL confirmSave;
@property (nonatomic,readonly,getter=shouldSaveAnyway) BOOL saveAnyway;
@property (nonatomic,readonly) CGFloat resizeImageValue;
@property (nonatomic,readonly) NSInteger resizeVideoValue;
@property (nonatomic,readonly) NSString *qualityFromSettings;
@property (nonatomic,copy) NSDictionary *settings;
+(instancetype)sharedSettings;
-(void)updateSettings;
-(NSString *)qualityForValue:(NSInteger)value;
@end

@interface UIImage (Resize)
+ (UIImage *)createScaledImageFromData:(NSData *)imageData;
@end

@implementation UIImage (Resize) 
+ (UIImage *)createScaledImageFromData:(NSData *)imageData {
	UIImage *originalImage = [UIImage imageWithData:imageData];
	CGFloat factor = [MSGAutoSaveSettings sharedSettings].resizeImageValue;
	CIContext *context = [CIContext contextWithOptions:nil];
	CIImage *inputImage = [CIImage imageWithCGImage:[originalImage CGImage]];
	CIFilter *filter = [CIFilter filterWithName:@"CILanczosScaleTransform"];
	[filter setValue:inputImage forKey:kCIInputImageKey];
	[filter setValue:[NSNumber numberWithDouble:factor] forKey:@"inputScale"];
	[filter setValue:@1.0 forKey:@"inputAspectRatio"];
	CIImage *result = [filter outputImage];
	CGImageRef cgImage = [context createCGImage:result fromRect:[result extent]];
	UIImage *imageResult = [UIImage imageWithCGImage:cgImage];
	CGImageRelease(cgImage);
	return imageResult;
}
@end

@implementation MSGAutoSaveSettings
@synthesize settings;

void settingsChanged(CFNotificationCenterRef center,
                           void * observer,
                           CFStringRef name,
                           const void * object,
                           CFDictionaryRef userInfo) {
  	[[MSGAutoSaveSettings sharedSettings] updateSettings];
}

+(instancetype)sharedSettings {
	static dispatch_once_t p = 0;

	__strong static MSGAutoSaveSettings *_sharedSettings = nil;

	dispatch_once(&p, ^{
		_sharedSettings = [[self alloc] init];
	});

	return _sharedSettings;
}

-(void)updateSettings {
	
	self.settings = nil;

	CFPreferencesAppSynchronize(CFSTR("com.sharedroutine.msgautosave"));
    CFArrayRef keyList = CFPreferencesCopyKeyList(CFSTR("com.sharedroutine.msgautosave"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost) ?: CFArrayCreate(NULL, NULL, 0, NULL);
    self.settings = (__bridge_transfer NSDictionary *)CFPreferencesCopyMultiple(keyList,CFSTR("com.sharedroutine.msgautosave"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    CFRelease(keyList);

}

-(instancetype)init {

	self = [super init];

	if (self) {
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, settingsChanged, CFSTR("MSGAutoSaveUpdateSettingsNotification"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
		[self updateSettings];
	}

	return self;
}

-(BOOL)isEnabled {
	id value = self.settings[@"kEnabled"];
	return value ? [value boolValue] : TRUE;
}

-(BOOL)shouldConfirmSave {
	id value = self.settings[@"kConfirmSave"];
	return value ? [value boolValue] : FALSE;
}

-(BOOL)shouldSaveAnyway {
	id value = self.settings[@"kSaveAnyway"];
	return value ? [value boolValue] : TRUE;
}

-(CGFloat)resizeImageValue {
	id value = self.settings[@"kResizeValue"];
	return value ? (CGFloat)[value floatValue] : (CGFloat)1.0;
}

-(NSInteger)resizeVideoValue {
	id value = self.settings[@"kResizeVideoValue"];
	return value ? [value integerValue] : -1;
}

-(NSString *)qualityForValue:(NSInteger)value {

	switch (value) {

		case 0:
			return AVAssetExportPresetLowQuality;
		break;

		case 1:
			return AVAssetExportPresetMediumQuality;
		break;

		case 2:
			return AVAssetExportPresetHighestQuality;
		break;

		default:
			return @"not supported";
		break;

	}
}

-(NSString *)qualityFromSettings {
	return [self qualityForValue:self.resizeVideoValue];
}

@end

@interface MSGAutoSave : NSObject
-(void)autosaveInBackground;
+(instancetype)sharedInstance;
-(void)prepare;
@property (nonatomic,strong) NSMutableArray *transferGUIDs;
@property (nonatomic,strong) ALAssetsLibrary *assetsLibrary;
@property (nonatomic,strong) SBLaunchAppListener *launchListener;
@property (nonatomic,strong) AVAssetExportSession *exportSession;
@property (nonatomic) NSInteger confirmationToken;
@end

@implementation MSGAutoSave
@synthesize transferGUIDs,assetsLibrary,launchListener,exportSession,confirmationToken = _confirmationToken;

+(instancetype)sharedInstance {
	static dispatch_once_t p = 0;

	__strong static MSGAutoSave *_sharedSelf = nil;

	dispatch_once(&p, ^{
		_sharedSelf = [[self alloc] init];
		_sharedSelf.assetsLibrary = [[ALAssetsLibrary alloc] init];
		_sharedSelf.transferGUIDs = [NSMutableArray array];
		static int confToken = 0;
		notify_register_check("com.sharedroutine.MSGAutoSave-confirmation",&confToken);
		[_sharedSelf setConfirmationToken:confToken];
	});

	return _sharedSelf;
}

-(void)autosaveInBackground {
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		[self autosave];
	});
}

//When in MobileSMS - autosave
-(void)notificationReceived:(NSNotification *)notification {
	NSArray *fileTransferGUIDs = notification.userInfo[@"kTransferGUIDs"];
	[self setTransferGUIDs:[fileTransferGUIDs mutableCopy]];
	if (![MSGAutoSaveSettings sharedSettings].shouldConfirmSave) { //no confirmation needed, save instantly in background
			[self autosaveInBackground];
	} else {
		notify_set_state(self.confirmationToken, fileTransferGUIDs.count); //store the count of files
		notify_post("com.sharedroutine.MSGAutoSave-confirmation");
	}
}

-(void)prepare {

	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationReceived:) name:@"MSGAutoSaveDoYourThingNotification" object:nil];

	//register for SpringBoard's confirmed notification
	static int confirmedToken = 0;
	notify_register_dispatch("com.sharedroutine.MSGAutoSave-confirmed", &confirmedToken, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(int token) {
		uint64_t response = -1;
		notify_get_state(confirmedToken,&response);
		if (response == 1) {  //save
			[self autosaveInBackground];
		}
	});
}

-(BOOL)isImageMimeType:(NSString *)mimeType {
	return ([mimeType rangeOfString:@"image/"].location != NSNotFound);
}

-(BOOL)isVideoMimeType:(NSString *)mimeType {
	return ([mimeType rangeOfString:@"video/"].location != NSNotFound);
}

-(void)autosave {
	//Loop through the File Transfer IDs - In case someone send more files at a time

	void (^saveVideoAtURLBlock)(NSURL *videoURL) = ^(NSURL *videoURL) {
		//write video at url
		[self.assetsLibrary writeVideoAtPathToSavedPhotosAlbum:videoURL completionBlock:^(NSURL *assetURL, NSError *error) {
			if (error) {
				NSLog(@"[MSGAutoSave failed to save asset with error: %@]",error.description);
			}
		}];
	};

	for (NSString *guid in self.transferGUIDs) {
		IMFileTransfer *fileTransfer = [[%c(IMFileTransferCenter) sharedInstance] transferForGUID:guid];
		if (fileTransfer == nil) {
			continue; //skip this transfer, it is nil
		}
		[self.assetsLibrary assetForURL:fileTransfer.localURL resultBlock:^(ALAsset *asset) {
			//create an NSData object from the file URL
			NSData *fileData = [NSData dataWithContentsOfURL:fileTransfer.localURL];
			if ([self isImageMimeType:fileTransfer.mimeType] && fileData) { //is of type image
				//resize image - if user does not want it ot be resized, the size is multiplied by 1.0 so it stays the same
				UIImage *resizedImage = [UIImage createScaledImageFromData:fileData];
				//write to photo album
				[self.assetsLibrary writeImageToSavedPhotosAlbum:resizedImage.CGImage orientation:(ALAssetOrientation)[asset valueForProperty:ALAssetPropertyOrientation] completionBlock:^(NSURL *assetURL, NSError *error) {
					if (error) {
						NSLog(@"[MSGAutoSave failed to save asset with error: %@]",error.description);
					}
				}];
			} else if ([self isVideoMimeType:fileTransfer.mimeType] && fileData) { //is video type
				NSURL *videoURL = fileTransfer.localURL;
				NSString *fileName = fileTransfer.filename;
				NSString *extension = [fileName pathExtension];
				AVAsset *videoAsset = [AVAsset assetWithURL:videoURL];

				//check if it is possible to resize or if resizing is requested by user
				NSArray *compatiblePresets = [AVAssetExportSession exportPresetsCompatibleWithAsset:videoAsset];
				if (![compatiblePresets containsObject:[[MSGAutoSaveSettings sharedSettings] qualityFromSettings]]) {
					NSLog(@"[MSGAutoSave %@]",[MSGAutoSaveSettings sharedSettings].resizeVideoValue == -1 ? @"Resize Value is set to -1. No resizing requested" : @"video presets not compatible with video");
					saveVideoAtURLBlock(videoURL);
					return;
				}
				//initialize export session
				self.exportSession = [[AVAssetExportSession alloc] initWithAsset:videoAsset presetName:[[MSGAutoSaveSettings sharedSettings] qualityFromSettings]];
				self.exportSession.outputFileType = AVFileTypeQuickTimeMovie;
				self.exportSession.outputURL = [[videoURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@_exported.%@",fileName,extension]];
				[self.exportSession exportAsynchronouslyWithCompletionHandler:^{
					switch ([self.exportSession status]) {
						case AVAssetExportSessionStatusCompleted:
							NSLog(@"[MSGAutoSave exportCompleted]");
							saveVideoAtURLBlock(self.exportSession.outputURL);
						break;

						case AVAssetExportSessionStatusExporting:
							NSLog(@"[MSGAutoSave exporting]");
						break;

						case AVAssetExportSessionStatusFailed:
							NSLog(@"[MSGAutoSave failedWithError:%@]",self.exportSession.error.description);
							if ([MSGAutoSaveSettings sharedSettings].shouldSaveAnyway) { //save original anyway
								saveVideoAtURLBlock(videoURL);
							} 
						break;

						case AVAssetExportSessionStatusCancelled:
							NSLog(@"[MSGAutoSave cancelled]");
						break;

						case AVAssetExportSessionStatusWaiting:
							NSLog(@"[MSGAutoSave waiting]");
						break;

						case AVAssetExportSessionStatusUnknown:
							NSLog(@"[MSGAutoSave unknownStatus]");
						break;

						default:
							NSLog(@"[MSGAutoSave defaultCaseEntered]");
						break;
					}
				}];
			}
		} failureBlock:^(NSError *error) {
			NSLog(@"[MSGAutoSave failed to get asset with error: %@]",error.description);
		}];
	}
	//clean up
	[self.transferGUIDs removeAllObjects];
}

@end

@interface IMAgentManager : NSObject
@property (nonatomic,getter=isRunning,setter=setIsRunning:) BOOL running;
@property (nonatomic,strong) NSArray *fileTransferGUIDs;
+(instancetype)sharedManager;
-(void)registerForNotifications;
-(void)postFileTransferGUIDs;
@end

@implementation IMAgentManager
@synthesize running,fileTransferGUIDs;

+(instancetype)sharedManager {
	static dispatch_once_t p = 0;

	__strong static IMAgentManager *_sharedSelf = nil;

	dispatch_once(&p, ^{
		_sharedSelf = [[self alloc] init];
		_sharedSelf.fileTransferGUIDs = [NSArray array];
	});

	return _sharedSelf;
}

-(void)registerForNotifications {
	static dispatch_once_t p = 0; //we only want to register those notifications once
	dispatch_once(&p,^{
		//register for MobileSMS to launch
		static int launchToken = 0;
		notify_register_dispatch("com.apple.MobileSMS-launched", &launchToken, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(int token) {
			[self setIsRunning:TRUE];
			[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"MSGAutoSaveDoYourThingNotification" object:nil userInfo:@{@"kTransferGUIDs":self.fileTransferGUIDs} deliverImmediately:YES];
	    });

		//register for MobileSMS to exit
	    static int exitToken = 0;
		notify_register_dispatch("com.apple.MobileSMS-exited", &exitToken, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(int token) {
			[self setIsRunning:FALSE];
	    });
	});
}

-(void)postFileTransferGUIDs {
	if (self.isRunning) { //if it is running, post a notification
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"MSGAutoSaveDoYourThingNotification" object:nil userInfo:@{@"kTransferGUIDs":self.fileTransferGUIDs} deliverImmediately:YES];
	}
	/*
		we do not need to post a notification when it is NOT running 
		because our registered notification observer block waits for the app to launch and post it then
	*/
}

@end

//hook imagent process to get when a message is being received. could not find a ChatKit notification that is posted :(
%group imagenthooks
%hook IMDServiceSession

- (void)didReceiveMessage:(FZMessage *)message forChat:(id)chat style:(unsigned char)style {
	%orig;

	if (message.isFinished && message.fileTransferGUIDs.count > 0) { //has any file to transfer
		//set file transfer guids
		[[IMAgentManager sharedManager] setFileTransferGUIDs:message.fileTransferGUIDs];
		//tell the manager to post a notification with the file transfer guids
		[[IMAgentManager sharedManager] postFileTransferGUIDs];
	}
}

%end
%end

void initializeSpringBoard() {
	//register a token for the response
	static int responseToken = 0;
	notify_register_check("com.sharedroutine.MSGAutoSave-confirmed",&responseToken);

	//wait for the confirmation notification
	static int alertToken = 0;
	notify_register_dispatch("com.sharedroutine.MSGAutoSave-confirmation", &alertToken, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(int token) {
		dispatch_async(dispatch_get_main_queue(),^{
			//get number of files
			uint64_t countFiles = -1;
			notify_get_state(token,&countFiles);

			//show confirmation alert
			BUIAlertView *av = [[BUIAlertView alloc] initWithTitle:@"Confirm Autosaving" message:[NSString stringWithFormat:@"Are you sure that you want to save %llu Files?",countFiles] delegate:nil cancelButtonTitle:@"Cancel" otherButtonTitles:@"Save", nil];
			[av showWithDismissBlock:^(UIAlertView *alertView, NSInteger buttonIndex, NSString *buttonTitle) {
				//setting the response value depending on the button that was clicked
		  		if (buttonIndex != alertView.cancelButtonIndex) {
		  			notify_set_state(responseToken, 1); //save = 1
		  		} else {
		  			notify_set_state(responseToken, 0); //cancel = 0	
		  		}
		  		notify_post("com.sharedroutine.MSGAutoSave-confirmed");
			}];
		});
	});
}

//constructor to initialize hooks and prepare
%ctor {
	NSString *processName = [[NSProcessInfo processInfo] processName];
	//check if it is enabled
	if ([MSGAutoSaveSettings sharedSettings].isEnabled) {
		if ([processName isEqualToString:@"MobileSMS"]) {
			[[MSGAutoSave sharedInstance] prepare];
		} else if ([processName isEqualToString:@"imagent"]) {
			//initialize the hooks and register notifications
			[[IMAgentManager sharedManager] registerForNotifications];
			%init(imagenthooks);
		} else if ([processName isEqualToString:@"SpringBoard"]) {
			static dispatch_once_t p = 0;
			dispatch_once(&p,^{
				initializeSpringBoard();
			});
		}
	}
}