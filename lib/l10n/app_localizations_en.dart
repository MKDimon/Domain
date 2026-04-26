// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Domain';

  @override
  String get navExplore => 'Explore';

  @override
  String get navLogin => 'Login';

  @override
  String get navRegister => 'Register';

  @override
  String get navLogout => 'Logout';

  @override
  String get navProfile => 'Profile';

  @override
  String get navAdmin => 'Admin';

  @override
  String get navHome => 'Home';

  @override
  String get navChat => 'Chat';

  @override
  String get navMenu => 'Menu';

  @override
  String get navBack => 'Back';

  @override
  String get authLoginTitle => 'Sign In';

  @override
  String get authLoginSubtitle => 'Sign in to your account';

  @override
  String get authRegisterTitle => 'Create Account';

  @override
  String get authRegisterSubtitle => 'Create your account';

  @override
  String get authUsername => 'Username';

  @override
  String get authUsernameOrEmail => 'Username or email';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authConfirmPassword => 'Confirm password';

  @override
  String get authFillAllFields => 'Please fill in all fields';

  @override
  String get authLoginFailed => 'Login failed';

  @override
  String get authRegistrationFailed => 'Registration failed';

  @override
  String get authPasswordsDontMatch => 'Passwords do not match';

  @override
  String get authPasswordTooShort => 'Password must be at least 6 characters';

  @override
  String get authPasswordMinLength => '6+ chars';

  @override
  String get authPasswordUppercase => 'Uppercase';

  @override
  String get authNoAccount => 'Don\'t have an account?';

  @override
  String get authHasAccount => 'Already have an account?';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authRegister => 'Register';

  @override
  String get authAgreeTerms =>
      'I agree to the Terms of Service and Privacy Policy';

  @override
  String get heroTitle => 'Build Your Community';

  @override
  String get heroSubtitle =>
      'Create pages, chat, share knowledge — all in one place';

  @override
  String get heroSearch => 'Search communities...';

  @override
  String get popularCommunities => 'Popular Communities';

  @override
  String get popularArticles => 'Popular Articles';

  @override
  String get viewAll => 'View all →';

  @override
  String get categories => 'Categories';

  @override
  String get ctaTitle => 'Start Your Community';

  @override
  String get ctaSubtitle =>
      'Create pages, manage members, build your knowledge base';

  @override
  String get ctaFeaturePages => 'Pages';

  @override
  String get ctaFeatureChat => 'Chat';

  @override
  String get ctaFeaturePlugins => 'Plugins';

  @override
  String get ctaFeaturePagesDesc => 'Page constructor\nwith plugins';

  @override
  String get ctaFeatureChatDesc => 'Real-time\ncommunication';

  @override
  String get ctaFeaturePluginsDesc => 'Wiki, polls, booking\nand more';

  @override
  String get ctaButton => 'Create Community';

  @override
  String get ctaFree => 'Free for up to 3 communities';

  @override
  String footerCopyright(String year) {
    return 'Domain © $year';
  }

  @override
  String communitiesCount(int count) {
    return '$count communities';
  }

  @override
  String get communitiesLabel => 'communities';

  @override
  String membersCount(int count) {
    return '$count';
  }

  @override
  String get members => 'members';

  @override
  String get pages => 'pages';

  @override
  String get pagesTitle => 'Pages';

  @override
  String get views => 'views';

  @override
  String get exploreBack => '← Back';

  @override
  String get exploreTitle => 'Explore';

  @override
  String get exploreCreate => 'Create';

  @override
  String get exploreNoCommunities => 'No communities found';

  @override
  String get exploreSearch => 'Search communities...';

  @override
  String get communityNotFound => 'Not found';

  @override
  String get communityBackToMain => '← Back to main';

  @override
  String get communityHome => 'Home';

  @override
  String get communityNoPages => 'No pages in this community yet.';

  @override
  String get communityLoadFailed => 'Failed to load community';

  @override
  String get createCommunityTitle => 'Create Community';

  @override
  String get createCommunityName => 'Name';

  @override
  String get createCommunityNamePlaceholder => 'My community';

  @override
  String get createCommunitySlug => 'Slug';

  @override
  String get createCommunitySlugPlaceholder => 'my-community';

  @override
  String get createCommunityDescription => 'Description (optional)';

  @override
  String get createCommunityDescriptionPlaceholder =>
      'What is your community about?';

  @override
  String get createCommunityVisibility => 'Visibility';

  @override
  String get createCommunityPublic => 'Public community';

  @override
  String get createCommunityPrivate => 'Private community';

  @override
  String get createCommunityPublicHint =>
      'Community is visible to all and anyone can join';

  @override
  String get createCommunityPrivateHint =>
      'Community is visible to members only. Invitation required to join.';

  @override
  String get createCommunityCreating => 'Creating...';

  @override
  String get createCommunityNameSlugRequired => 'Name and slug are required';

  @override
  String get createCommunityFailed => 'Failed to create community';

  @override
  String get createCommunityButton => 'Create community';

  @override
  String get pageViewBackToCommunity => 'Back to community';

  @override
  String get pageViewLoadFailed => 'Failed to load page';

  @override
  String get pageViewNoSections => 'This page has no sections yet.';

  @override
  String get chatTypeMessage => 'Type a message...';

  @override
  String get chatNoMessages => 'No messages yet. Start the conversation!';

  @override
  String get chatDeleteConfirm => 'Delete this message?';

  @override
  String get chatReply => 'Reply';

  @override
  String get chatDelete => 'Delete';

  @override
  String get chatReplyingTo => 'Replying to';

  @override
  String get chatCancelReply => 'Cancel reply';

  @override
  String get chatSend => 'Send';

  @override
  String get chatLoginToChat => 'Log in to participate';

  @override
  String get chatMissedCallOut => 'Call not answered';

  @override
  String get chatMissedCallIn => 'Missed call from';

  @override
  String get chatCallDeclined => 'Call declined';

  @override
  String get chatCallCancelled => 'You cancelled the call';

  @override
  String get chatCallYouDeclined => 'You declined a call from';

  @override
  String get chatVoiceCall => 'Voice call';

  @override
  String get chatVideoCall => 'Video call';

  @override
  String get chatScrollToBottom => 'Back to latest';

  @override
  String get chatJumpToDate => 'Jump to date';

  @override
  String get chatTypingSingle => 'typing...';

  @override
  String chatTypingOne(String name) {
    return '$name is typing...';
  }

  @override
  String chatTypingTwo(String name1, String name2) {
    return '$name1 and $name2 are typing...';
  }

  @override
  String chatTypingMany(String name1, String name2, int count) {
    return '$name1, $name2 and $count more are typing...';
  }

  @override
  String get commonAll => 'All';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonClose => 'Close';

  @override
  String get commonMore => 'More';

  @override
  String get commonLoading => 'Loading';

  @override
  String get commonRetry => 'Retry';

  @override
  String get themeLight => 'Light theme';

  @override
  String get themeDark => 'Dark theme';

  @override
  String get communityJoin => 'Join';

  @override
  String get communityLeave => 'Leave';

  @override
  String get communityMember => 'Member';

  @override
  String get communityOwner => 'Owner';

  @override
  String get communityModerator => 'Moderator';

  @override
  String get communitySections => 'Sections';

  @override
  String get communityPopularPages => 'Popular Pages';

  @override
  String get communityRecentChanges => 'Recent Changes';

  @override
  String get communitySettings => 'Settings';

  @override
  String get communityMembers => 'Members';

  @override
  String get communitySearch => 'Search in community...';

  @override
  String get communityVoice => 'Voice';

  @override
  String get communityFavorites => 'Favorites';

  @override
  String get communityMessages => 'Messages';

  @override
  String get communityNotifications => 'Notifications';

  @override
  String get communityEditHomePage => 'Edit homepage';

  @override
  String get communityReport => 'Report';

  @override
  String get reportTitle => 'Report';

  @override
  String get reportSubtitle =>
      'Your report will be reviewed by platform moderators within 24 hours.';

  @override
  String get reportTarget => 'Report target';

  @override
  String get reportCommentLabel => 'Comment (optional)';

  @override
  String get reportCommentHint => 'Describe the situation in detail...';

  @override
  String get reportSubmit => 'Submit';

  @override
  String get reportSending => 'Sending...';

  @override
  String get reportCancel => 'Cancel';

  @override
  String get reportSentTitle => 'Report submitted';

  @override
  String get reportSentMessage => 'We will review your report within 24 hours.';

  @override
  String get reportDone => 'Done';

  @override
  String get reportFailed => 'Failed to submit report';

  @override
  String get reportReasonSpam => 'Spam or advertising';

  @override
  String get reportReasonFraud => 'Fraud / phishing';

  @override
  String get reportReasonInsult => 'Insults / profanity';

  @override
  String get reportReasonExtremism => 'Extremism, hate speech';

  @override
  String get reportReasonAdult => 'Adult content (18+)';

  @override
  String get reportReasonCopyright => 'Copyright infringement';

  @override
  String get reportReasonThreat => 'Threats, incitement to violence';

  @override
  String get reportReasonOther => 'Other';

  @override
  String get voiceChannelEmpty => 'Channel is empty';

  @override
  String get voiceChannelEmptyHint => 'Click \"Join\" below to enter';

  @override
  String get voiceJoin => 'Join';

  @override
  String get voiceLeave => 'Leave';

  @override
  String get voiceMute => 'Mute';

  @override
  String get voiceUnmute => 'Unmute';

  @override
  String get voiceSettings => 'Audio settings';

  @override
  String voiceParticipants(Object count) {
    return '$count participant(s)';
  }

  @override
  String get voiceConnecting => 'Connecting...';

  @override
  String get voiceMicError => 'Failed to access microphone';

  @override
  String get voiceConnectionGood => 'Good connection';

  @override
  String get voiceConnectionOk => 'Average connection';

  @override
  String get voiceConnectionBad => 'Poor connection';

  @override
  String get voicePttHint => 'Hold this key to transmit voice';

  @override
  String get voiceActivationVad => 'Voice';

  @override
  String get voiceActivationPtt => 'Push-to-Talk (PTT)';

  @override
  String get voiceActivationMode => 'ACTIVATION MODE';

  @override
  String get voiceAudioProcessing => 'AUDIO PROCESSING';

  @override
  String get voiceEchoCancellation => 'Echo cancellation';

  @override
  String get voiceNoiseSuppression => 'Noise suppression';

  @override
  String get voiceVolume => 'VOLUME';

  @override
  String get voiceSfx => 'Sound effects';

  @override
  String get voicePttKey => 'PTT key';

  @override
  String get voicePttRecording => 'Press a key...';

  @override
  String get voiceSettingsTitle => 'Audio settings';

  @override
  String get voiceOnline => 'Online';

  @override
  String get voiceFloatingTitle => 'Voice channel';

  @override
  String get voiceDevices => 'DEVICES';

  @override
  String get voiceMicrophone => 'Microphone';

  @override
  String get voiceSpeaker => 'Speaker';

  @override
  String get voiceTestMic => 'Test microphone';

  @override
  String get voiceStopTest => 'Stop';

  @override
  String get voiceTestMicHint => 'Speak into microphone — the bar should move';

  @override
  String get voiceInputVolume => 'Microphone';

  @override
  String get voiceOutputVolume => 'Speaker';

  @override
  String get voiceNoiseFilter => 'Noise suppression';

  @override
  String get voiceNfOff => 'Off';

  @override
  String get voiceNfBuiltin => 'Built-in (WebRTC NS)';

  @override
  String get voiceNfRnnoise => 'RNNoise (AI) — coming soon';

  @override
  String get voiceNfHintOff => 'Noise suppression is off';

  @override
  String get voiceNfHintBuiltin =>
      'Built-in WebRTC NS — basic background noise suppression';

  @override
  String get voiceEcHint => 'Suppresses echo from speakers';

  @override
  String get voiceAutoVad => 'Auto threshold';

  @override
  String get voiceAutoVadHint =>
      'Automatically adjusts to background noise level';

  @override
  String get voiceSensitivity => 'Sensitivity';

  @override
  String get voiceSensitivityHint =>
      'Lower — catches whispers, higher — loud voice only';

  @override
  String get voiceReset => 'Reset';

  @override
  String get voiceDone => 'Done';

  @override
  String get voiceMuteHotkey => 'MUTE HOTKEY';

  @override
  String get voiceMuteKeyNotSet => 'Not set';

  @override
  String get voiceMuteKeyHint => 'Works even when the window is minimized';

  @override
  String get voiceMuteKeyRecording => 'Press a combination...';

  @override
  String get inboxConversations => 'Conversations';

  @override
  String get inboxNoConversations => 'No conversations';

  @override
  String get inboxStartConversation => 'Start a conversation';

  @override
  String get inboxSelectConversation => 'Select a conversation';

  @override
  String get inboxJustNow => 'just now';

  @override
  String get chatSearchMessages => 'Search messages...';

  @override
  String get chatNoSearchResults => 'No results found';

  @override
  String get chatSearchHint => 'Enter query...';

  @override
  String get chatToday => 'Today';

  @override
  String get chatYesterday => 'Yesterday';

  @override
  String get pricingLoading => 'Loading...';

  @override
  String get pricingTitle => 'Pricing';

  @override
  String get pricingSubtitle => 'Choose the plan that fits your communities';

  @override
  String get pricingMonthly => 'Monthly';

  @override
  String get pricingYearly => 'Yearly';

  @override
  String get pricingMonth => 'mo';

  @override
  String get pricingForever => 'forever';

  @override
  String get pricingRecommended => 'Recommended';

  @override
  String pricingTrialTitle(int days) {
    return 'Try Pro free for $days days';
  }

  @override
  String get pricingTrialHint => 'Full access to all Pro features at no cost';

  @override
  String get pricingStartTrial => 'Start free trial';

  @override
  String get pricingTrialAvailableSoon => 'Trial will be available soon';

  @override
  String get pricingStartFree => 'Start free';

  @override
  String get pricingUpgradePro => 'Upgrade to Pro';

  @override
  String get pricingRedirecting => 'Redirecting to checkout...';

  @override
  String get pricingPayFailed => 'Payment failed';

  @override
  String get pricingFreePriceSub => 'Free forever, no time limit';

  @override
  String get pricingMonthlyBillingSub => 'Billed monthly';

  @override
  String pricingYearlyBillingSub(int total, int savings) {
    return '$total₽/yr, save $savings₽';
  }

  @override
  String get pricingFreeTagline => 'Everything you need to get started';

  @override
  String pricingFreeCommunities(int n) {
    return 'Up to $n communities';
  }

  @override
  String get pricingFreeStorage => 'Basic file storage';

  @override
  String get pricingFreePlugins => 'All core section plugins';

  @override
  String get pricingFreeAnalytics => 'Basic visit analytics';

  @override
  String get pricingFreeAdmins => 'Owner-only administration';

  @override
  String get pricingProTagline => 'Full control and scaling';

  @override
  String get pricingProIncludesFree => 'Everything in Free, plus:';

  @override
  String pricingProCommunities(int n) {
    return 'Up to $n communities';
  }

  @override
  String get pricingProStorage => 'Expanded storage + pay-as-you-go';

  @override
  String get pricingProAnalytics => 'Advanced analytics and export';

  @override
  String pricingProModerators(int n) {
    return 'Up to $n co-admins/moderators';
  }

  @override
  String get pricingProAutomod => 'Banned-words auto-moderation';

  @override
  String get pricingProExport => 'Community data export';

  @override
  String get pricingProWhitelabel => 'White-label: hide branding';

  @override
  String get pricingProNoAds => 'No ad widget';

  @override
  String get pricingFaqTitle => 'Frequently asked questions';

  @override
  String get pricingFaqRefundQ => 'Can I get a refund?';

  @override
  String pricingFaqRefundA(int days) {
    return 'Yes, within $days days of payment — contact support.';
  }

  @override
  String get pricingFaqCancelQ => 'How do I cancel my subscription?';

  @override
  String get pricingFaqCancelA =>
      'In the Billing section of your profile. Your subscription stays active until the end of the period.';

  @override
  String get pricingFaqRenewQ => 'Does the subscription renew automatically?';

  @override
  String get pricingFaqRenewA =>
      'No, there is no auto-renewal. You renew manually.';

  @override
  String get pricingFaqDowngradeQ => 'What happens if I switch to Free?';

  @override
  String get pricingFaqDowngradeA =>
      'Your communities remain, but Pro features will be restricted.';

  @override
  String get pricingOfferNote => 'Terms and details — see the ';

  @override
  String get pricingOfferLink => 'public offer';

  @override
  String get billingTierFree => 'Free';

  @override
  String get billingTierPro => 'Pro';

  @override
  String get billingPageTitle => 'Billing and subscription';

  @override
  String get billingPageSubtitle => 'Manage your plan and payment history';

  @override
  String get billingActiveUntil => 'Active until';

  @override
  String get billingFreeHint =>
      'Free tier. Upgrade to Pro to unlock more features.';

  @override
  String get billingRenewOrChange => 'Renew / change';

  @override
  String get billingInvoiceHistory => 'Payment history';

  @override
  String get billingLoading => 'Loading...';

  @override
  String get billingEmptyInvoices => 'No payments';

  @override
  String get billingColDate => 'Date';

  @override
  String get billingColDesc => 'Description';

  @override
  String get billingColMethod => 'Method';

  @override
  String get billingColAmount => 'Amount';

  @override
  String get billingColStatus => 'Status';

  @override
  String get billingStatusPending => 'Pending';

  @override
  String get billingStatusWaiting => 'Processing';

  @override
  String get billingStatusSucceeded => 'Paid';

  @override
  String get billingStatusCanceled => 'Canceled';

  @override
  String get billingMethodBankCard => 'Bank card';

  @override
  String get billingProcessingTitle => 'Processing payment';

  @override
  String get billingProcessingDesc =>
      'Waiting for confirmation from payment system...';

  @override
  String get billingSuccessTitle => 'Pro subscription activated';

  @override
  String billingSuccessDesc(String period) {
    return 'Pro is active for: $period. Redirecting to profile...';
  }

  @override
  String get billingCanceledTitle => 'Payment canceled';

  @override
  String get billingCanceledDesc =>
      'Payment did not go through. Try again or choose another payment method.';

  @override
  String get billingGoToProfile => 'Go to profile';

  @override
  String get billingTryAgain => 'Try again';

  @override
  String get billingNoPaymentId => 'Missing payment ID';

  @override
  String get billingStatusFetchFailed => 'Failed to fetch payment status';

  @override
  String get upgradeGoPro => 'Upgrade to Pro';

  @override
  String get upgradeNotNow => 'Not now';

  @override
  String get upgradeClose => 'Close';

  @override
  String get upgradeCurrentUsage => 'In use';

  @override
  String get upgradeCommunityLimitTitle => 'Community limit reached';

  @override
  String get upgradeCommunityLimitDesc =>
      'Free tier allows up to 3 communities. Upgrade to Pro to create more.';

  @override
  String get upgradeCommunityLimitB1 => 'Up to 10 communities';

  @override
  String get upgradeCommunityLimitB2 => 'Expanded storage';

  @override
  String get upgradeCommunityLimitB3 => 'Co-admins and auto-moderation';

  @override
  String get upgradeWhitelabelTitle => 'Remove \"Powered by Domain\"';

  @override
  String get upgradeWhitelabelDesc =>
      'White-label lets you hide platform branding from your pages.';

  @override
  String get upgradeWhitelabelB1 => 'Full branding removal';

  @override
  String get upgradeWhitelabelB2 => 'Extended customization';

  @override
  String get upgradeWhitelabelB3 => 'Professional look';

  @override
  String get upgradeExportTitle => 'Export is a Pro feature';

  @override
  String get upgradeExportDesc =>
      'Export your community data for backup or migration.';

  @override
  String get upgradeExportB1 => 'Full data export';

  @override
  String get upgradeExportB2 => 'CSV and JSON formats';

  @override
  String get upgradeExportB3 => 'Backup support';

  @override
  String get upgradeStorageTitle => 'Storage full';

  @override
  String get upgradeStorageDesc =>
      'You\'ve reached the storage limit. Upgrade to Pro for more space.';

  @override
  String get upgradeStorageB1 => 'Increased file limit';

  @override
  String get upgradeStorageB2 => 'Pay-as-you-go for extra space';

  @override
  String get upgradeStorageB3 => 'Large file support';

  @override
  String get upgradeCoadminTitle => 'Need a second moderator?';

  @override
  String get upgradeCoadminDesc =>
      'Free tier allows owner-only management. Pro unlocks co-admins.';

  @override
  String get upgradeCoadminB1 => 'Up to 5 moderators';

  @override
  String get upgradeCoadminB2 => 'Flexible roles and permissions';

  @override
  String get upgradeCoadminB3 => 'Team management';

  @override
  String get upgradeModerationTitle => 'Auto-moderation is a Pro feature';

  @override
  String get upgradeModerationDesc =>
      'Automatic banned-word filtering is available on Pro.';

  @override
  String get upgradeModerationB1 => 'Banned words filter';

  @override
  String get upgradeModerationB2 => 'Automatic removal';

  @override
  String get upgradeModerationB3 => 'Customizable lists';

  @override
  String get upgradeWebappTitle => 'Web mini-apps — Pro feature';

  @override
  String get upgradeWebappDesc =>
      'Lua scripts with HTTP API are only available on Pro.';

  @override
  String get upgradeWebappB1 => 'Lua sandbox';

  @override
  String get upgradeWebappB2 => 'HTTP API for scripts';

  @override
  String get upgradeWebappB3 => 'Interactive sections';
}
