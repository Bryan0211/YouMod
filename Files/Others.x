#import "Headers.h"

Class YTILikeResponseClass, YTIDislikeResponseClass, YTIRemoveLikeResponseClass;

// Background playback
%group BackgroundPlayback
%hook YTIBackgroundOfflineSettingCategoryEntryRenderer
%new(B@:)
- (BOOL)isBackgroundEnabled { return YES; }
%end
%end

%hook MLVideo
- (BOOL)playableInBackground { return IS_ENABLED(BackgroundPlayback) ? YES : %orig; }
%end

%hook YTIPlayabilityStatus
- (BOOL)isPlayableInBackground { return IS_ENABLED(BackgroundPlayback) ? YES : %orig; }
%end

%hook YTPlaybackData
- (BOOL)isPlayableInBackground { return IS_ENABLED(BackgroundPlayback) ? YES : %orig; }
%end

%hook YTIPlayerResponse
- (BOOL)isPlayableInBackground { return IS_ENABLED(BackgroundPlayback) ? YES : %orig; }
%end

// Try to disable Shorts PiP
%hook YTColdConfig
- (BOOL)shortsPlayerGlobalConfigEnableReelsPictureInPicture { return IS_ENABLED(DisablesShortsPiP) ? NO : %orig; }
- (BOOL)shortsPlayerGlobalConfigEnableReelsPictureInPictureIos { return IS_ENABLED(DisablesShortsPiP) ? NO : %orig; }
%end

%hook YTHotConfig
- (BOOL)shortsPlayerGlobalConfigEnableReelsPictureInPictureAllowedFromPlayer { return IS_ENABLED(DisablesShortsPiP) ? NO : %orig; }
%end

%hook YTReelModel
- (BOOL)isPiPSupported { return IS_ENABLED(DisablesShortsPiP) ? NO : %orig; }
%end

%hook YTReelPlayerViewController
- (BOOL)isPictureInPictureAllowed { return IS_ENABLED(DisablesShortsPiP) ? NO : %orig; }
%end

%hook YTReelWatchRootViewController
- (void)switchToPictureInPicture { if (!IS_ENABLED(DisablesShortsPiP)) %orig; }
%end

// Block upgrade dialogs
%hook YTGlobalConfig
- (BOOL)shouldBlockUpgradeDialog { return IS_ENABLED(BlockUpgradeDialogs) ? YES : %orig; }
- (BOOL)shouldShowUpgradeDialog { return IS_ENABLED(BlockUpgradeDialogs) ? NO : %orig; }
- (BOOL)shouldShowUpgrade { return IS_ENABLED(BlockUpgradeDialogs) ? NO : %orig; }
- (BOOL)shouldForceUpgrade { return IS_ENABLED(BlockUpgradeDialogs) ? NO : %orig; }
%end

// Prevent YouTube from asking "Are you there?"
%hook YTColdConfig
- (BOOL)enableYouthereCommandsOnIos { return IS_ENABLED(BlockUpgradeDialogs) ? NO : %orig; }
%end

%hook YTYouThereController
- (BOOL)shouldShowYouTherePrompt { return IS_ENABLED(HideAreYouThereDialog) ? NO : %orig; }
- (void)showYouTherePrompt { if (!IS_ENABLED(HideAreYouThereDialog)) %orig; }
%end

%hook YTYouThereControllerImpl
- (BOOL)shouldShowYouTherePrompt { return IS_ENABLED(HideAreYouThereDialog) ? NO : %orig; }
- (void)showYouTherePrompt { if (!IS_ENABLED(HideAreYouThereDialog)) %orig; }
%end

// Fixes slow miniplayer
%hook YTColdConfig
- (BOOL)enableIosFloatingMiniplayerDoubleTapToResize { return IS_ENABLED(FixesSlowMiniPlayer) ? NO : %orig; }
%end

// Use old miniplayer
%hook YTColdConfig
- (BOOL)enableIosFloatingMiniplayer { return IS_ENABLED(DisablesNewMiniPlayer) ? NO : %orig; }
%end

// Disables Snackbar
%hook GOOHUDManagerInternal
- (id)sharedInstance { return IS_ENABLED(DisablesSnackBar) ? nil : %orig; }
- (void)showMessageMainThread:(id)arg { if (!IS_ENABLED(DisablesSnackBar)) %orig; }
- (void)activateOverlay:(id)arg { if (!IS_ENABLED(DisablesSnackBar)) %orig; }
- (void)displayHUDViewForMessage:(id)arg { if (!IS_ENABLED(DisablesSnackBar)) %orig; }
%end

// Hide startup animations
%hook YTColdConfig
- (BOOL)mainAppCoreClientIosEnableStartupAnimation { return IS_ENABLED(HideStartupAni) ? NO : %orig; }
%end

// Remove "Play next in queue" from the menu @PoomSmart (https://github.com/qnblackcat/uYouPlus/issues/1138#issuecomment-1606415080)
%hook YTMenuItemVisibilityHandler
- (BOOL)shouldShowServiceItemRenderer:(YTIMenuConditionalServiceItemRenderer *)renderer {
    if (renderer.icon.iconType == 251 && IS_ENABLED(HidePlayInNextQueue)) {
        return NO;
    } return %orig;
}
%end

%hook YTMenuItemVisibilityHandlerImpl
- (BOOL)shouldShowServiceItemRenderer:(YTIMenuConditionalServiceItemRenderer *)renderer {
    if (renderer.icon.iconType == 251 && IS_ENABLED(HidePlayInNextQueue)) {
        return NO;
    } return %orig;
}
%end

/* untested
// Remove Download button from the menu
%hook YTDefaultSheetController
- (void)addAction:(YTActionSheetAction *)action {
    NSString *identifier = [action valueForKey:@"_accessibilityIdentifier"];

    NSDictionary *actionsToRemove = @{
        @"7": @(ytlBool(@"removeDownloadMenu")),
        @"1": @(ytlBool(@"removeWatchLaterMenu")),
        @"3": @(ytlBool(@"removeSaveToPlaylistMenu")),
        @"5": @(ytlBool(@"removeShareMenu")),
        @"12": @(ytlBool(@"removeNotInterestedMenu")),
        @"31": @(ytlBool(@"removeDontRecommendMenu")),
        @"58": @(ytlBool(@"removeReportMenu"))
    };

    if (![actionsToRemove[identifier] boolValue]) {
        %orig;
    }
}
%end
*/

static __weak id YouModActivePlaylistSheetController;
static BOOL YouModPendingPlaylistSheet;
static CFTimeInterval YouModPendingPlaylistSheetExpiresAt;

static BOOL YouModIsSaveToPlaylistEntryIdentifier(NSString *identifier) {
    return [identifier isEqualToString:@"3"] || [identifier isEqualToString:@"id.video.add_to.button"];
}

static BOOL YouModIdentifierLooksLikePlaylist(NSString *identifier) {
    if (identifier.length == 0) return NO;
    return [identifier rangeOfString:@"playlist" options:NSCaseInsensitiveSearch].location != NSNotFound;
}

static void YouModMarkPlaylistPopupPending(void) {
    YouModPendingPlaylistSheet = YES;
    YouModPendingPlaylistSheetExpiresAt = CFAbsoluteTimeGetCurrent() + 30.0;
}

static BOOL YouModShouldUsePendingPlaylistSheet(void) {
    if (!YouModPendingPlaylistSheet) return NO;
    if (CFAbsoluteTimeGetCurrent() <= YouModPendingPlaylistSheetExpiresAt) return YES;
    YouModPendingPlaylistSheet = NO;
    return NO;
}

static NSString *YouModSafeStringForKey(id object, NSString *key) {
    @try {
        id value = [object valueForKey:key];
        return [value isKindOfClass:NSString.class] ? value : nil;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static BOOL YouModStringLooksLikePlaylistPopup(NSString *string) {
    if (string.length == 0) return NO;
    NSArray <NSString *> *needles = @[
        @"playlist",
        @"播放清單",
        @"播放列表",
        @"再生リスト",
        @"재생목록"
    ];
    for (NSString *needle in needles) {
        if ([string rangeOfString:needle options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

static BOOL YouModActionLooksLikePlaylistPopupAction(YTActionSheetAction *action) {
    NSString *identifier = YouModSafeStringForKey(action, @"_accessibilityIdentifier");
    if (YouModIsSaveToPlaylistEntryIdentifier(identifier) || YouModIdentifierLooksLikePlaylist(identifier)) return YES;

    UIButton *button = action.button;
    NSString *buttonIdentifier = button.accessibilityIdentifier;
    if (YouModIsSaveToPlaylistEntryIdentifier(buttonIdentifier) || YouModIdentifierLooksLikePlaylist(buttonIdentifier)) return YES;

    return YouModStringLooksLikePlaylistPopup(button.accessibilityLabel)
        || YouModStringLooksLikePlaylistPopup(button.currentTitle)
        || YouModStringLooksLikePlaylistPopup(button.titleLabel.text);
}

static BOOL YouModIsSaveToPlaylistAction(YTActionSheetAction *action) {
    NSString *identifier = YouModSafeStringForKey(action, @"_accessibilityIdentifier");
    if (YouModIsSaveToPlaylistEntryIdentifier(identifier)) return YES;

    UIButton *button = action.button;
    return YouModIsSaveToPlaylistEntryIdentifier(button.accessibilityIdentifier);
}

static void YouModConfigurePlaylistPopupAction(YTActionSheetAction *action) {
    action.shouldDismissOnAction = IS_ENABLED(AutoClosePlaylistPopup);
}

static void YouModWrapSaveToPlaylistHandler(YTActionSheetAction *action) {
    id handler = action.handler;
    if (!handler) return;

    void (^originalHandler)(void) = [handler copy];
    action.handler = ^{
        YouModMarkPlaylistPopupPending();
        originalHandler();
    };
}

%hook YTDefaultSheetController
- (void)addAction:(YTActionSheetAction *)action {
    if (YouModIsSaveToPlaylistAction(action)) {
        YouModWrapSaveToPlaylistHandler(action);
    } else {
        if (YouModActivePlaylistSheetController == self || YouModActionLooksLikePlaylistPopupAction(action)) {
            YouModActivePlaylistSheetController = self;
        } else if (YouModShouldUsePendingPlaylistSheet()) {
            YouModPendingPlaylistSheet = NO;
            YouModActivePlaylistSheetController = self;
        }

        if (YouModActivePlaylistSheetController == self) {
            YouModConfigurePlaylistPopupAction(action);
        }
    }
    %orig;
}

- (void)dealloc {
    if (YouModActivePlaylistSheetController == self) {
        YouModActivePlaylistSheetController = nil;
    }
    %orig;
}
%end

%hook UIControl
- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event {
    if (YouModIsSaveToPlaylistEntryIdentifier(self.accessibilityIdentifier)) {
        YouModMarkPlaylistPopupPending();
    }
    %orig;
}
%end

%hook _ASDisplayView
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (YouModIsSaveToPlaylistEntryIdentifier(self.accessibilityIdentifier)) {
        YouModMarkPlaylistPopupPending();
    }
    %orig;
}
%end

// YTSlientVote (https://github.com/PoomSmart/YTSilentVote)
%group SlientVote
%hook YTInnerTubeResponseWrapper
- (id)initWithResponse:(id)response cacheContext:(id)arg2 requestStatistics:(id)arg3 mutableSharedData:(id)arg4 {
    if ([response isKindOfClass:YTILikeResponseClass]
        || [response isKindOfClass:YTIDislikeResponseClass]
        || [response isKindOfClass:YTIRemoveLikeResponseClass]) return nil;
    return %orig;
}
%end
%end

%ctor {
    YTILikeResponseClass = %c(YTILikeResponse);
    YTIDislikeResponseClass = %c(YTIDislikeResponse);
    YTIRemoveLikeResponseClass = %c(YTIRemoveLikeResponse);
    %init;
    if (IS_ENABLED(HideLikeDislikeVotes)) {
        %init(SlientVote);
    }
    if (IS_ENABLED(BackgroundPlayback)) {
        %init(BackgroundPlayback);
    }
}
