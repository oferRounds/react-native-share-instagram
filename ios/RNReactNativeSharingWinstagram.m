#import "RNReactNativeSharingWinstagram.h"
#import "AQSInstagramActivity.h"
#include "Constants.h"

#import <Social/Social.h>
#import <Accounts/Accounts.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTConvert.h>
#import <React/RCTLog.h>
#import <React/RCTUIManager.h>
#import <React/RCTUtils.h>

@import Photos;

@implementation RNReactNativeSharingWinstagram

@synthesize bridge = _bridge;

- (dispatch_queue_t)methodQueue {
    return dispatch_get_main_queue();
}

RCT_EXPORT_MODULE()

# pragma mark - Is installed

- (NSDictionary *)constantsToExport {
    return @{
             @"instagram":[[UIApplication sharedApplication] canOpenURL: [NSURL URLWithString: kInstagramURLScheme]] ? @(YES) : @(NO),
             @"whatsapp":[[UIApplication sharedApplication] canOpenURL: [NSURL URLWithString:kWhatsappURLScheme]] ? @(YES) : @(NO),
             @"twitter": [SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter] ? @(YES) : @(NO),
             @"facebook":[SLComposeViewController isAvailableForServiceType:SLServiceTypeFacebook] ? @(YES) : @(NO)
             };
}


# pragma mark - General sharing

RCT_EXPORT_METHOD(share:(NSString *)base64Image copy:(NSString *)copy andUrl:(NSString *)url) {

    UIImage *image = [UIImage imageWithData: [[NSData alloc]initWithBase64EncodedString:base64Image options:NSDataBase64DecodingIgnoreUnknownCharacters]];

    if (!image) {
        return;
    }

    AQSInstagramActivity *activity = [[AQSInstagramActivity alloc] init];
    NSArray *items = @[copy, [[NSURL alloc]initWithString:url], image];

    UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:@[activity]];
    activityController.excludedActivityTypes = @[UIActivityTypeAssignToContact, UIActivityTypePrint, UIActivityTypeAddToReadingList, UIActivityTypeCopyToPasteboard, UIActivityTypeOpenInIBooks];

    UIViewController *rootController = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    [rootController presentViewController:activityController animated:YES completion:NULL];
}

# pragma mark - Sharing WITH callback

RCT_EXPORT_METHOD(shareWithInstagram:(NSString *)fileName
                  base64Image:(NSString *)base64Image
                  localIdentifier:(NSString *)localIdentifier
                  successCallback:(RCTResponseSenderBlock)successCallback
                  failureCallback:(RCTResponseErrorBlock)failureCallback) {
    if ([[UIApplication sharedApplication] canOpenURL: [NSURL URLWithString:kInstagramURLScheme]]) {
        PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
        if (status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusDenied) {
            [self savePicAndOpenInstagram: base64Image
                          localIdentifier: localIdentifier
                          failureCallback: failureCallback
                          successCallback: successCallback];;
        }
        else if (status == PHAuthorizationStatusNotDetermined) {
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                if (status == PHAuthorizationStatusAuthorized) {
                    [self savePicAndOpenInstagram: base64Image
                                  localIdentifier: localIdentifier
                                  failureCallback: failureCallback
                                  successCallback: successCallback];
                }
            }];
        }
    } else {
        NSString *errorMessage = @"Not installed";
        NSDictionary *userInfo = @{NSLocalizedFailureReasonErrorKey: NSLocalizedString(errorMessage, nil)};
        NSError *error = [NSError errorWithDomain:@"com.rnshare" code:1 userInfo:userInfo];
        failureCallback(error);
    }
}

RCT_EXPORT_METHOD(shareWithTwitter:(NSString *)copy andUrl:(NSString *)url
                  failureCallback:(RCTResponseErrorBlock)failureCallback
                  successCallback:(RCTResponseSenderBlock)successCallback) {
    if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter]) {
        SLComposeViewController *twPostSheet = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter];
        [twPostSheet setInitialText:copy];
        [twPostSheet addURL:[NSURL URLWithString:url]];

        UIViewController *controller = RCTPresentedViewController();
        twPostSheet.completionHandler = ^(SLComposeViewControllerResult result) {
            if (result == SLComposeViewControllerResultDone) {
                successCallback(@[]);
            } else {
                NSString *errorMessage = @"Cancelled";
                NSDictionary *userInfo = @{NSLocalizedFailureReasonErrorKey: NSLocalizedString(errorMessage, nil)};
                NSError *error = [NSError errorWithDomain:@"com.rnshare" code:1 userInfo:userInfo];
                failureCallback(error);
            }
        };
        [controller presentViewController:twPostSheet animated:YES completion:nil];
    } else {
        NSString *errorMessage = @"Not installed";
        NSDictionary *userInfo = @{NSLocalizedFailureReasonErrorKey: NSLocalizedString(errorMessage, nil)};
        NSError *error = [NSError errorWithDomain:@"com.rnshare" code:1 userInfo:userInfo];
        failureCallback(error);
    }
}

RCT_EXPORT_METHOD(shareWithWhatsapp:(NSString *)copy andUrl:(NSString *)url
                  failureCallback:(RCTResponseErrorBlock)failureCallback
                  successCallback:(RCTResponseSenderBlock)successCallback) {
    if ([[UIApplication sharedApplication] canOpenURL: [NSURL URLWithString:kWhatsappURLScheme]]) {
        copy = [copy stringByAppendingString:@" "];
        copy = [copy stringByAppendingString:url];
        copy = [copy stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
        NSURL *whatsappURL = [NSURL URLWithString:[NSString stringWithFormat:kWhatsappSendTextURLScheme, copy]];
        [[UIApplication sharedApplication] openURL:whatsappURL];
        successCallback(@[]);

    } else {
        NSString *errorMessage = @"Not installed";
        NSDictionary *userInfo = @{NSLocalizedFailureReasonErrorKey: NSLocalizedString(errorMessage, nil)};
        NSError *error = [NSError errorWithDomain:@"com.rnshare" code:1 userInfo:userInfo];
        failureCallback(error);
    }
}

RCT_EXPORT_METHOD(shareWithFacebook:(NSString *)copy andUrl:(NSString *)url
                  failureCallback:(RCTResponseErrorBlock)failureCallback
                  successCallback:(RCTResponseSenderBlock)successCallback) {
    if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeFacebook]) {
        SLComposeViewController *fbPostSheet = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeFacebook];
        [fbPostSheet setInitialText:copy];
        [fbPostSheet addURL:[NSURL URLWithString:url]];

        UIViewController *controller = RCTPresentedViewController();
        fbPostSheet.completionHandler = ^(SLComposeViewControllerResult result) {
            if (result == SLComposeViewControllerResultDone) {
                successCallback(@[]);
            } else {
                NSString *errorMessage = @"Cancelled";
                NSDictionary *userInfo = @{NSLocalizedFailureReasonErrorKey: NSLocalizedString(errorMessage, nil)};
                NSError *error = [NSError errorWithDomain:@"com.rnshare" code:1 userInfo:userInfo];
                failureCallback(error);
            }
        };
        [controller presentViewController:fbPostSheet animated:YES completion:nil];

    } else {
        NSString *errorMessage = @"Not installed";
        NSDictionary *userInfo = @{NSLocalizedFailureReasonErrorKey: NSLocalizedString(errorMessage, nil)};
        NSError *error = [NSError errorWithDomain:@"com.rnshare" code:1 userInfo:userInfo];
        failureCallback(error);
    }
}

# pragma mark - Helpers

-(void)loadPhotoWithIdentifier:(NSString *)identifier resultHandler:(void (^)(UIImage *__nullable result, NSDictionary *__nullable info))resultHandler {
    
    PHAssetCollection *assetCollection = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumUserLibrary options:nil].firstObject;

    if (assetCollection == nil) {
        if (resultHandler != nil) {
            resultHandler(nil, nil);
        }
        
        return;
    }
    
    PHFetchOptions *fetchOptions = [PHFetchOptions new];
    fetchOptions.predicate = [NSPredicate predicateWithFormat:@"localIdentifier = %@", identifier];
    PHFetchResult<PHAsset *> *fetchResult = [PHAsset fetchAssetsInAssetCollection:assetCollection options:fetchOptions];
    
    if (fetchResult.count > 0) {
        PHAsset *asset = fetchResult.firstObject;
        PHImageRequestOptions *options = [PHImageRequestOptions new];
        options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
        options.networkAccessAllowed = YES;
        options.synchronous = NO;
        
        [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:CGSizeMake(asset.pixelWidth, asset.pixelHeight) contentMode:PHImageContentModeAspectFit options:options resultHandler:resultHandler];
    } else {
        if (resultHandler != nil) {
            resultHandler(nil, nil);
        }
    }
}

-(void)savePicAndOpenInstagram:(NSString*)base64Image
               localIdentifier:(NSString *)localIdentifier
               failureCallback:(RCTResponseErrorBlock)failureCallback
               successCallback:(RCTResponseSenderBlock)successCallback {
    
    NSURL *instagramURL = [NSURL URLWithString:[NSString stringWithFormat:kInstagramLibraryURLScheme, localIdentifier]];
    
    __weak typeof(RNReactNativeSharingWinstagram) *weakSelf = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([[UIApplication sharedApplication] canOpenURL:instagramURL]) {
            [weakSelf loadPhotoWithIdentifier:localIdentifier resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
                if (result != nil) {
                    [[UIApplication sharedApplication] openURL:instagramURL options:@{} completionHandler:NULL];
                    if (successCallback != NULL) {
                        successCallback(@[]);
                    }
                } else {
                     [weakSelf helperForSavePicAndOpenInstagram:base64Image localIdentifier:localIdentifier failureCallback:failureCallback successCallback:successCallback];
                }
            }];
            
        } else {
            [weakSelf helperForSavePicAndOpenInstagram:base64Image localIdentifier:localIdentifier failureCallback:failureCallback successCallback:successCallback];
        }
    });
}

-(void)helperForSavePicAndOpenInstagram:(NSString*)base64Image
               localIdentifier:(NSString *)localIdentifier
               failureCallback:(RCTResponseErrorBlock)failureCallback
               successCallback:(RCTResponseSenderBlock)successCallback {
    UIImage *image = [UIImage imageWithData: [[NSData alloc]initWithBase64EncodedString:base64Image options:NSDataBase64DecodingIgnoreUnknownCharacters]];
    
    if (!image) {
        return;
    }
    
    NSURL *URL = [self nilOrFileURLWithImageDataTemporary:UIImageJPEGRepresentation(image, 0.9)];
    
    __block PHAssetChangeRequest *_mChangeRequest = nil;
    __block PHObjectPlaceholder *placeholder;
    
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        
        NSData *pngData = [NSData dataWithContentsOfURL:URL];
        UIImage *image = [UIImage imageWithData:pngData];
        
        _mChangeRequest = [PHAssetChangeRequest creationRequestForAssetFromImage:image];
        
        placeholder = _mChangeRequest.placeholderForCreatedAsset;
        
    } completionHandler:^(BOOL success, NSError *error) {
        
        if (success) {
            NSURL *instagramURL = [NSURL URLWithString:[NSString stringWithFormat:kInstagramLibraryURLScheme, [placeholder localIdentifier]]];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([[UIApplication sharedApplication] canOpenURL:instagramURL]) {
                    [[UIApplication sharedApplication] openURL:instagramURL options:@{} completionHandler:NULL];
                    if (successCallback != NULL) {
                        successCallback(@[]);
                    }
                }
            });
        }
        else {
            if (failureCallback != NULL) {
                failureCallback(error);
            }
            
            NSLog(@"write error : %@",error);
        }
    }];\
}

- (NSURL *)nilOrFileURLWithImageDataTemporary:(NSData *)data {
    NSString *writePath = [NSTemporaryDirectory() stringByAppendingPathComponent:kInstagramPath];
    if (![data writeToFile:writePath atomically:YES]) {
        return nil;
    }

    return [NSURL fileURLWithPath:writePath];
}

- (UIDocumentInteractionController *)documentInteractionControllerForInstagramWithFileURL:(NSURL *)URL withCaptionText:(NSString *)textOrNil {
    UIDocumentInteractionController *controller = [UIDocumentInteractionController interactionControllerWithURL:URL];
    [controller setUTI:kInstagramUTI];
    if (textOrNil == nil) {
        textOrNil = @"";
    }
    controller.delegate = self;
    return controller;
}

@end
