import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Domain'**
  String get appName;

  /// No description provided for @navExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get navExplore;

  /// No description provided for @navLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get navLogin;

  /// No description provided for @navRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get navRegister;

  /// No description provided for @navLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get navLogout;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get navAdmin;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get navMenu;

  /// No description provided for @navBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get navBack;

  /// No description provided for @authLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get authLoginTitle;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your account'**
  String get authLoginSubtitle;

  /// No description provided for @authRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get authRegisterTitle;

  /// No description provided for @authRegisterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get authRegisterSubtitle;

  /// No description provided for @authUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get authUsername;

  /// No description provided for @authUsernameOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Username or email'**
  String get authUsernameOrEmail;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authConfirmPassword;

  /// No description provided for @authFillAllFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all fields'**
  String get authFillAllFields;

  /// No description provided for @authLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get authLoginFailed;

  /// No description provided for @authRegistrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed'**
  String get authRegistrationFailed;

  /// No description provided for @authPasswordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get authPasswordsDontMatch;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get authPasswordTooShort;

  /// No description provided for @authPasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'6+ chars'**
  String get authPasswordMinLength;

  /// No description provided for @authPasswordUppercase.
  ///
  /// In en, this message translates to:
  /// **'Uppercase'**
  String get authPasswordUppercase;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get authNoAccount;

  /// No description provided for @authHasAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get authHasAccount;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignIn;

  /// No description provided for @authRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get authRegister;

  /// No description provided for @authAgreeTerms.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms of Service and Privacy Policy'**
  String get authAgreeTerms;

  /// No description provided for @heroTitle.
  ///
  /// In en, this message translates to:
  /// **'Build Your Community'**
  String get heroTitle;

  /// No description provided for @heroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create pages, chat, share knowledge — all in one place'**
  String get heroSubtitle;

  /// No description provided for @heroSearch.
  ///
  /// In en, this message translates to:
  /// **'Search communities...'**
  String get heroSearch;

  /// No description provided for @popularCommunities.
  ///
  /// In en, this message translates to:
  /// **'Popular Communities'**
  String get popularCommunities;

  /// No description provided for @popularArticles.
  ///
  /// In en, this message translates to:
  /// **'Popular Articles'**
  String get popularArticles;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all →'**
  String get viewAll;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @ctaTitle.
  ///
  /// In en, this message translates to:
  /// **'Start Your Community'**
  String get ctaTitle;

  /// No description provided for @ctaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create pages, manage members, build your knowledge base'**
  String get ctaSubtitle;

  /// No description provided for @ctaFeaturePages.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get ctaFeaturePages;

  /// No description provided for @ctaFeatureChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get ctaFeatureChat;

  /// No description provided for @ctaFeaturePlugins.
  ///
  /// In en, this message translates to:
  /// **'Plugins'**
  String get ctaFeaturePlugins;

  /// No description provided for @ctaFeaturePagesDesc.
  ///
  /// In en, this message translates to:
  /// **'Page constructor\nwith plugins'**
  String get ctaFeaturePagesDesc;

  /// No description provided for @ctaFeatureChatDesc.
  ///
  /// In en, this message translates to:
  /// **'Real-time\ncommunication'**
  String get ctaFeatureChatDesc;

  /// No description provided for @ctaFeaturePluginsDesc.
  ///
  /// In en, this message translates to:
  /// **'Wiki, polls, booking\nand more'**
  String get ctaFeaturePluginsDesc;

  /// No description provided for @ctaButton.
  ///
  /// In en, this message translates to:
  /// **'Create Community'**
  String get ctaButton;

  /// No description provided for @ctaFree.
  ///
  /// In en, this message translates to:
  /// **'Free for up to 3 communities'**
  String get ctaFree;

  /// No description provided for @footerCopyright.
  ///
  /// In en, this message translates to:
  /// **'Domain © {year}'**
  String footerCopyright(String year);

  /// No description provided for @communitiesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} communities'**
  String communitiesCount(int count);

  /// No description provided for @communitiesLabel.
  ///
  /// In en, this message translates to:
  /// **'communities'**
  String get communitiesLabel;

  /// No description provided for @membersCount.
  ///
  /// In en, this message translates to:
  /// **'{count}'**
  String membersCount(int count);

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'members'**
  String get members;

  /// No description provided for @pages.
  ///
  /// In en, this message translates to:
  /// **'pages'**
  String get pages;

  /// No description provided for @pagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get pagesTitle;

  /// No description provided for @views.
  ///
  /// In en, this message translates to:
  /// **'views'**
  String get views;

  /// No description provided for @exploreBack.
  ///
  /// In en, this message translates to:
  /// **'← Back'**
  String get exploreBack;

  /// No description provided for @exploreTitle.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get exploreTitle;

  /// No description provided for @exploreCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get exploreCreate;

  /// No description provided for @exploreNoCommunities.
  ///
  /// In en, this message translates to:
  /// **'No communities found'**
  String get exploreNoCommunities;

  /// No description provided for @exploreSearch.
  ///
  /// In en, this message translates to:
  /// **'Search communities...'**
  String get exploreSearch;

  /// No description provided for @communityNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get communityNotFound;

  /// No description provided for @communityBackToMain.
  ///
  /// In en, this message translates to:
  /// **'← Back to main'**
  String get communityBackToMain;

  /// No description provided for @communityHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get communityHome;

  /// No description provided for @communityNoPages.
  ///
  /// In en, this message translates to:
  /// **'No pages in this community yet.'**
  String get communityNoPages;

  /// No description provided for @communityLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load community'**
  String get communityLoadFailed;

  /// No description provided for @createCommunityTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Community'**
  String get createCommunityTitle;

  /// No description provided for @createCommunityName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get createCommunityName;

  /// No description provided for @createCommunityNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'My community'**
  String get createCommunityNamePlaceholder;

  /// No description provided for @createCommunitySlug.
  ///
  /// In en, this message translates to:
  /// **'Slug'**
  String get createCommunitySlug;

  /// No description provided for @createCommunitySlugPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'my-community'**
  String get createCommunitySlugPlaceholder;

  /// No description provided for @createCommunityDescription.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get createCommunityDescription;

  /// No description provided for @createCommunityDescriptionPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'What is your community about?'**
  String get createCommunityDescriptionPlaceholder;

  /// No description provided for @createCommunityVisibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get createCommunityVisibility;

  /// No description provided for @createCommunityPublic.
  ///
  /// In en, this message translates to:
  /// **'Public community'**
  String get createCommunityPublic;

  /// No description provided for @createCommunityPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private community'**
  String get createCommunityPrivate;

  /// No description provided for @createCommunityPublicHint.
  ///
  /// In en, this message translates to:
  /// **'Community is visible to all and anyone can join'**
  String get createCommunityPublicHint;

  /// No description provided for @createCommunityPrivateHint.
  ///
  /// In en, this message translates to:
  /// **'Community is visible to members only. Invitation required to join.'**
  String get createCommunityPrivateHint;

  /// No description provided for @createCommunityCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get createCommunityCreating;

  /// No description provided for @createCommunityNameSlugRequired.
  ///
  /// In en, this message translates to:
  /// **'Name and slug are required'**
  String get createCommunityNameSlugRequired;

  /// No description provided for @createCommunityFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create community'**
  String get createCommunityFailed;

  /// No description provided for @createCommunityButton.
  ///
  /// In en, this message translates to:
  /// **'Create community'**
  String get createCommunityButton;

  /// No description provided for @pageViewBackToCommunity.
  ///
  /// In en, this message translates to:
  /// **'Back to community'**
  String get pageViewBackToCommunity;

  /// No description provided for @pageViewLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load page'**
  String get pageViewLoadFailed;

  /// No description provided for @pageViewNoSections.
  ///
  /// In en, this message translates to:
  /// **'This page has no sections yet.'**
  String get pageViewNoSections;

  /// No description provided for @chatTypeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get chatTypeMessage;

  /// No description provided for @chatNoMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Start the conversation!'**
  String get chatNoMessages;

  /// No description provided for @chatDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this message?'**
  String get chatDeleteConfirm;

  /// No description provided for @chatReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get chatReply;

  /// No description provided for @chatDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatDelete;

  /// No description provided for @chatReplyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to'**
  String get chatReplyingTo;

  /// No description provided for @chatCancelReply.
  ///
  /// In en, this message translates to:
  /// **'Cancel reply'**
  String get chatCancelReply;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatLoginToChat.
  ///
  /// In en, this message translates to:
  /// **'Log in to participate'**
  String get chatLoginToChat;

  /// No description provided for @chatMissedCallOut.
  ///
  /// In en, this message translates to:
  /// **'Call not answered'**
  String get chatMissedCallOut;

  /// No description provided for @chatMissedCallIn.
  ///
  /// In en, this message translates to:
  /// **'Missed call from'**
  String get chatMissedCallIn;

  /// No description provided for @chatCallDeclined.
  ///
  /// In en, this message translates to:
  /// **'Call declined'**
  String get chatCallDeclined;

  /// No description provided for @chatCallCancelled.
  ///
  /// In en, this message translates to:
  /// **'You cancelled the call'**
  String get chatCallCancelled;

  /// No description provided for @chatCallYouDeclined.
  ///
  /// In en, this message translates to:
  /// **'You declined a call from'**
  String get chatCallYouDeclined;

  /// No description provided for @chatVoiceCall.
  ///
  /// In en, this message translates to:
  /// **'Voice call'**
  String get chatVoiceCall;

  /// No description provided for @chatVideoCall.
  ///
  /// In en, this message translates to:
  /// **'Video call'**
  String get chatVideoCall;

  /// No description provided for @chatScrollToBottom.
  ///
  /// In en, this message translates to:
  /// **'Back to latest'**
  String get chatScrollToBottom;

  /// No description provided for @chatJumpToDate.
  ///
  /// In en, this message translates to:
  /// **'Jump to date'**
  String get chatJumpToDate;

  /// No description provided for @chatTypingSingle.
  ///
  /// In en, this message translates to:
  /// **'typing...'**
  String get chatTypingSingle;

  /// No description provided for @chatTypingOne.
  ///
  /// In en, this message translates to:
  /// **'{name} is typing...'**
  String chatTypingOne(String name);

  /// No description provided for @chatTypingTwo.
  ///
  /// In en, this message translates to:
  /// **'{name1} and {name2} are typing...'**
  String chatTypingTwo(String name1, String name2);

  /// No description provided for @chatTypingMany.
  ///
  /// In en, this message translates to:
  /// **'{name1}, {name2} and {count} more are typing...'**
  String chatTypingMany(String name1, String name2, int count);

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get commonMore;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get commonLoading;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light theme'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark theme'**
  String get themeDark;

  /// No description provided for @communityJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get communityJoin;

  /// No description provided for @communityLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get communityLeave;

  /// No description provided for @communityMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get communityMember;

  /// No description provided for @communityOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get communityOwner;

  /// No description provided for @communityModerator.
  ///
  /// In en, this message translates to:
  /// **'Moderator'**
  String get communityModerator;

  /// No description provided for @communitySections.
  ///
  /// In en, this message translates to:
  /// **'Sections'**
  String get communitySections;

  /// No description provided for @communityPopularPages.
  ///
  /// In en, this message translates to:
  /// **'Popular Pages'**
  String get communityPopularPages;

  /// No description provided for @communityRecentChanges.
  ///
  /// In en, this message translates to:
  /// **'Recent Changes'**
  String get communityRecentChanges;

  /// No description provided for @communitySettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get communitySettings;

  /// No description provided for @communityMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get communityMembers;

  /// No description provided for @communitySearch.
  ///
  /// In en, this message translates to:
  /// **'Search in community...'**
  String get communitySearch;

  /// No description provided for @communityVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get communityVoice;

  /// No description provided for @communityFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get communityFavorites;

  /// No description provided for @communityMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get communityMessages;

  /// No description provided for @communityNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get communityNotifications;

  /// No description provided for @communityEditHomePage.
  ///
  /// In en, this message translates to:
  /// **'Edit homepage'**
  String get communityEditHomePage;

  /// No description provided for @communityReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get communityReport;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get reportTitle;

  /// No description provided for @reportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your report will be reviewed by platform moderators within 24 hours.'**
  String get reportSubtitle;

  /// No description provided for @reportTarget.
  ///
  /// In en, this message translates to:
  /// **'Report target'**
  String get reportTarget;

  /// No description provided for @reportCommentLabel.
  ///
  /// In en, this message translates to:
  /// **'Comment (optional)'**
  String get reportCommentLabel;

  /// No description provided for @reportCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the situation in detail...'**
  String get reportCommentHint;

  /// No description provided for @reportSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get reportSubmit;

  /// No description provided for @reportSending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get reportSending;

  /// No description provided for @reportCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get reportCancel;

  /// No description provided for @reportSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Report submitted'**
  String get reportSentTitle;

  /// No description provided for @reportSentMessage.
  ///
  /// In en, this message translates to:
  /// **'We will review your report within 24 hours.'**
  String get reportSentMessage;

  /// No description provided for @reportDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get reportDone;

  /// No description provided for @reportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit report'**
  String get reportFailed;

  /// No description provided for @reportReasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam or advertising'**
  String get reportReasonSpam;

  /// No description provided for @reportReasonFraud.
  ///
  /// In en, this message translates to:
  /// **'Fraud / phishing'**
  String get reportReasonFraud;

  /// No description provided for @reportReasonInsult.
  ///
  /// In en, this message translates to:
  /// **'Insults / profanity'**
  String get reportReasonInsult;

  /// No description provided for @reportReasonExtremism.
  ///
  /// In en, this message translates to:
  /// **'Extremism, hate speech'**
  String get reportReasonExtremism;

  /// No description provided for @reportReasonAdult.
  ///
  /// In en, this message translates to:
  /// **'Adult content (18+)'**
  String get reportReasonAdult;

  /// No description provided for @reportReasonCopyright.
  ///
  /// In en, this message translates to:
  /// **'Copyright infringement'**
  String get reportReasonCopyright;

  /// No description provided for @reportReasonThreat.
  ///
  /// In en, this message translates to:
  /// **'Threats, incitement to violence'**
  String get reportReasonThreat;

  /// No description provided for @reportReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reportReasonOther;

  /// No description provided for @voiceChannelEmpty.
  ///
  /// In en, this message translates to:
  /// **'Channel is empty'**
  String get voiceChannelEmpty;

  /// No description provided for @voiceChannelEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Click \"Join\" below to enter'**
  String get voiceChannelEmptyHint;

  /// No description provided for @voiceJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get voiceJoin;

  /// No description provided for @voiceLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get voiceLeave;

  /// No description provided for @voiceMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get voiceMute;

  /// No description provided for @voiceUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get voiceUnmute;

  /// No description provided for @voiceSettings.
  ///
  /// In en, this message translates to:
  /// **'Audio settings'**
  String get voiceSettings;

  /// No description provided for @voiceParticipants.
  ///
  /// In en, this message translates to:
  /// **'{count} participant(s)'**
  String voiceParticipants(Object count);

  /// No description provided for @voiceConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get voiceConnecting;

  /// No description provided for @voiceMicError.
  ///
  /// In en, this message translates to:
  /// **'Failed to access microphone'**
  String get voiceMicError;

  /// No description provided for @voiceConnectionGood.
  ///
  /// In en, this message translates to:
  /// **'Good connection'**
  String get voiceConnectionGood;

  /// No description provided for @voiceConnectionOk.
  ///
  /// In en, this message translates to:
  /// **'Average connection'**
  String get voiceConnectionOk;

  /// No description provided for @voiceConnectionBad.
  ///
  /// In en, this message translates to:
  /// **'Poor connection'**
  String get voiceConnectionBad;

  /// No description provided for @voicePttHint.
  ///
  /// In en, this message translates to:
  /// **'Hold this key to transmit voice'**
  String get voicePttHint;

  /// No description provided for @voiceActivationVad.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voiceActivationVad;

  /// No description provided for @voiceActivationPtt.
  ///
  /// In en, this message translates to:
  /// **'Push-to-Talk (PTT)'**
  String get voiceActivationPtt;

  /// No description provided for @voiceActivationMode.
  ///
  /// In en, this message translates to:
  /// **'ACTIVATION MODE'**
  String get voiceActivationMode;

  /// No description provided for @voiceAudioProcessing.
  ///
  /// In en, this message translates to:
  /// **'AUDIO PROCESSING'**
  String get voiceAudioProcessing;

  /// No description provided for @voiceEchoCancellation.
  ///
  /// In en, this message translates to:
  /// **'Echo cancellation'**
  String get voiceEchoCancellation;

  /// No description provided for @voiceNoiseSuppression.
  ///
  /// In en, this message translates to:
  /// **'Noise suppression'**
  String get voiceNoiseSuppression;

  /// No description provided for @voiceVolume.
  ///
  /// In en, this message translates to:
  /// **'VOLUME'**
  String get voiceVolume;

  /// No description provided for @voiceSfx.
  ///
  /// In en, this message translates to:
  /// **'Sound effects'**
  String get voiceSfx;

  /// No description provided for @voicePttKey.
  ///
  /// In en, this message translates to:
  /// **'PTT key'**
  String get voicePttKey;

  /// No description provided for @voicePttRecording.
  ///
  /// In en, this message translates to:
  /// **'Press a key...'**
  String get voicePttRecording;

  /// No description provided for @voiceSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Audio settings'**
  String get voiceSettingsTitle;

  /// No description provided for @voiceOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get voiceOnline;

  /// No description provided for @voiceFloatingTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice channel'**
  String get voiceFloatingTitle;

  /// No description provided for @voiceDevices.
  ///
  /// In en, this message translates to:
  /// **'DEVICES'**
  String get voiceDevices;

  /// No description provided for @voiceMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get voiceMicrophone;

  /// No description provided for @voiceSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get voiceSpeaker;

  /// No description provided for @voiceTestMic.
  ///
  /// In en, this message translates to:
  /// **'Test microphone'**
  String get voiceTestMic;

  /// No description provided for @voiceStopTest.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get voiceStopTest;

  /// No description provided for @voiceTestMicHint.
  ///
  /// In en, this message translates to:
  /// **'Speak into microphone — the bar should move'**
  String get voiceTestMicHint;

  /// No description provided for @voiceInputVolume.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get voiceInputVolume;

  /// No description provided for @voiceOutputVolume.
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get voiceOutputVolume;

  /// No description provided for @voiceNoiseFilter.
  ///
  /// In en, this message translates to:
  /// **'Noise suppression'**
  String get voiceNoiseFilter;

  /// No description provided for @voiceNfOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get voiceNfOff;

  /// No description provided for @voiceNfBuiltin.
  ///
  /// In en, this message translates to:
  /// **'Built-in (WebRTC NS)'**
  String get voiceNfBuiltin;

  /// No description provided for @voiceNfRnnoise.
  ///
  /// In en, this message translates to:
  /// **'RNNoise (AI) — coming soon'**
  String get voiceNfRnnoise;

  /// No description provided for @voiceNfHintOff.
  ///
  /// In en, this message translates to:
  /// **'Noise suppression is off'**
  String get voiceNfHintOff;

  /// No description provided for @voiceNfHintBuiltin.
  ///
  /// In en, this message translates to:
  /// **'Built-in WebRTC NS — basic background noise suppression'**
  String get voiceNfHintBuiltin;

  /// No description provided for @voiceEcHint.
  ///
  /// In en, this message translates to:
  /// **'Suppresses echo from speakers'**
  String get voiceEcHint;

  /// No description provided for @voiceAutoVad.
  ///
  /// In en, this message translates to:
  /// **'Auto threshold'**
  String get voiceAutoVad;

  /// No description provided for @voiceAutoVadHint.
  ///
  /// In en, this message translates to:
  /// **'Automatically adjusts to background noise level'**
  String get voiceAutoVadHint;

  /// No description provided for @voiceSensitivity.
  ///
  /// In en, this message translates to:
  /// **'Sensitivity'**
  String get voiceSensitivity;

  /// No description provided for @voiceSensitivityHint.
  ///
  /// In en, this message translates to:
  /// **'Lower — catches whispers, higher — loud voice only'**
  String get voiceSensitivityHint;

  /// No description provided for @voiceReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get voiceReset;

  /// No description provided for @voiceDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get voiceDone;

  /// No description provided for @voiceMuteHotkey.
  ///
  /// In en, this message translates to:
  /// **'MUTE HOTKEY'**
  String get voiceMuteHotkey;

  /// No description provided for @voiceMuteKeyNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get voiceMuteKeyNotSet;

  /// No description provided for @voiceMuteKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Works even when the window is minimized'**
  String get voiceMuteKeyHint;

  /// No description provided for @voiceMuteKeyRecording.
  ///
  /// In en, this message translates to:
  /// **'Press a combination...'**
  String get voiceMuteKeyRecording;

  /// No description provided for @inboxConversations.
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get inboxConversations;

  /// No description provided for @inboxNoConversations.
  ///
  /// In en, this message translates to:
  /// **'No conversations'**
  String get inboxNoConversations;

  /// No description provided for @inboxStartConversation.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation'**
  String get inboxStartConversation;

  /// No description provided for @inboxSelectConversation.
  ///
  /// In en, this message translates to:
  /// **'Select a conversation'**
  String get inboxSelectConversation;

  /// No description provided for @inboxJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get inboxJustNow;

  /// No description provided for @chatSearchMessages.
  ///
  /// In en, this message translates to:
  /// **'Search messages...'**
  String get chatSearchMessages;

  /// No description provided for @chatNoSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get chatNoSearchResults;

  /// No description provided for @chatSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Enter query...'**
  String get chatSearchHint;

  /// No description provided for @chatToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get chatToday;

  /// No description provided for @chatYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get chatYesterday;

  /// No description provided for @pricingLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get pricingLoading;

  /// No description provided for @pricingTitle.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get pricingTitle;

  /// No description provided for @pricingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the plan that fits your communities'**
  String get pricingSubtitle;

  /// No description provided for @pricingMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get pricingMonthly;

  /// No description provided for @pricingYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get pricingYearly;

  /// No description provided for @pricingMonth.
  ///
  /// In en, this message translates to:
  /// **'mo'**
  String get pricingMonth;

  /// No description provided for @pricingForever.
  ///
  /// In en, this message translates to:
  /// **'forever'**
  String get pricingForever;

  /// No description provided for @pricingRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get pricingRecommended;

  /// No description provided for @pricingTrialTitle.
  ///
  /// In en, this message translates to:
  /// **'Try Pro free for {days} days'**
  String pricingTrialTitle(int days);

  /// No description provided for @pricingTrialHint.
  ///
  /// In en, this message translates to:
  /// **'Full access to all Pro features at no cost'**
  String get pricingTrialHint;

  /// No description provided for @pricingStartTrial.
  ///
  /// In en, this message translates to:
  /// **'Start free trial'**
  String get pricingStartTrial;

  /// No description provided for @pricingTrialAvailableSoon.
  ///
  /// In en, this message translates to:
  /// **'Trial will be available soon'**
  String get pricingTrialAvailableSoon;

  /// No description provided for @pricingStartFree.
  ///
  /// In en, this message translates to:
  /// **'Start free'**
  String get pricingStartFree;

  /// No description provided for @pricingUpgradePro.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get pricingUpgradePro;

  /// No description provided for @pricingRedirecting.
  ///
  /// In en, this message translates to:
  /// **'Redirecting to checkout...'**
  String get pricingRedirecting;

  /// No description provided for @pricingPayFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get pricingPayFailed;

  /// No description provided for @pricingFreePriceSub.
  ///
  /// In en, this message translates to:
  /// **'Free forever, no time limit'**
  String get pricingFreePriceSub;

  /// No description provided for @pricingMonthlyBillingSub.
  ///
  /// In en, this message translates to:
  /// **'Billed monthly'**
  String get pricingMonthlyBillingSub;

  /// No description provided for @pricingYearlyBillingSub.
  ///
  /// In en, this message translates to:
  /// **'{total}₽/yr, save {savings}₽'**
  String pricingYearlyBillingSub(int total, int savings);

  /// No description provided for @pricingFreeTagline.
  ///
  /// In en, this message translates to:
  /// **'Everything you need to get started'**
  String get pricingFreeTagline;

  /// No description provided for @pricingFreeCommunities.
  ///
  /// In en, this message translates to:
  /// **'Up to {n} communities'**
  String pricingFreeCommunities(int n);

  /// No description provided for @pricingFreeStorage.
  ///
  /// In en, this message translates to:
  /// **'Basic file storage'**
  String get pricingFreeStorage;

  /// No description provided for @pricingFreePlugins.
  ///
  /// In en, this message translates to:
  /// **'All core section plugins'**
  String get pricingFreePlugins;

  /// No description provided for @pricingFreeAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Basic visit analytics'**
  String get pricingFreeAnalytics;

  /// No description provided for @pricingFreeAdmins.
  ///
  /// In en, this message translates to:
  /// **'Owner-only administration'**
  String get pricingFreeAdmins;

  /// No description provided for @pricingProTagline.
  ///
  /// In en, this message translates to:
  /// **'Full control and scaling'**
  String get pricingProTagline;

  /// No description provided for @pricingProIncludesFree.
  ///
  /// In en, this message translates to:
  /// **'Everything in Free, plus:'**
  String get pricingProIncludesFree;

  /// No description provided for @pricingProCommunities.
  ///
  /// In en, this message translates to:
  /// **'Up to {n} communities'**
  String pricingProCommunities(int n);

  /// No description provided for @pricingProStorage.
  ///
  /// In en, this message translates to:
  /// **'Expanded storage + pay-as-you-go'**
  String get pricingProStorage;

  /// No description provided for @pricingProAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Advanced analytics and export'**
  String get pricingProAnalytics;

  /// No description provided for @pricingProModerators.
  ///
  /// In en, this message translates to:
  /// **'Up to {n} co-admins/moderators'**
  String pricingProModerators(int n);

  /// No description provided for @pricingProAutomod.
  ///
  /// In en, this message translates to:
  /// **'Banned-words auto-moderation'**
  String get pricingProAutomod;

  /// No description provided for @pricingProExport.
  ///
  /// In en, this message translates to:
  /// **'Community data export'**
  String get pricingProExport;

  /// No description provided for @pricingProWhitelabel.
  ///
  /// In en, this message translates to:
  /// **'White-label: hide branding'**
  String get pricingProWhitelabel;

  /// No description provided for @pricingProNoAds.
  ///
  /// In en, this message translates to:
  /// **'No ad widget'**
  String get pricingProNoAds;

  /// No description provided for @pricingFaqTitle.
  ///
  /// In en, this message translates to:
  /// **'Frequently asked questions'**
  String get pricingFaqTitle;

  /// No description provided for @pricingFaqRefundQ.
  ///
  /// In en, this message translates to:
  /// **'Can I get a refund?'**
  String get pricingFaqRefundQ;

  /// No description provided for @pricingFaqRefundA.
  ///
  /// In en, this message translates to:
  /// **'Yes, within {days} days of payment — contact support.'**
  String pricingFaqRefundA(int days);

  /// No description provided for @pricingFaqCancelQ.
  ///
  /// In en, this message translates to:
  /// **'How do I cancel my subscription?'**
  String get pricingFaqCancelQ;

  /// No description provided for @pricingFaqCancelA.
  ///
  /// In en, this message translates to:
  /// **'In the Billing section of your profile. Your subscription stays active until the end of the period.'**
  String get pricingFaqCancelA;

  /// No description provided for @pricingFaqRenewQ.
  ///
  /// In en, this message translates to:
  /// **'Does the subscription renew automatically?'**
  String get pricingFaqRenewQ;

  /// No description provided for @pricingFaqRenewA.
  ///
  /// In en, this message translates to:
  /// **'No, there is no auto-renewal. You renew manually.'**
  String get pricingFaqRenewA;

  /// No description provided for @pricingFaqDowngradeQ.
  ///
  /// In en, this message translates to:
  /// **'What happens if I switch to Free?'**
  String get pricingFaqDowngradeQ;

  /// No description provided for @pricingFaqDowngradeA.
  ///
  /// In en, this message translates to:
  /// **'Your communities remain, but Pro features will be restricted.'**
  String get pricingFaqDowngradeA;

  /// No description provided for @pricingOfferNote.
  ///
  /// In en, this message translates to:
  /// **'Terms and details — see the '**
  String get pricingOfferNote;

  /// No description provided for @pricingOfferLink.
  ///
  /// In en, this message translates to:
  /// **'public offer'**
  String get pricingOfferLink;

  /// No description provided for @billingTierFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get billingTierFree;

  /// No description provided for @billingTierPro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get billingTierPro;

  /// No description provided for @billingPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Billing and subscription'**
  String get billingPageTitle;

  /// No description provided for @billingPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your plan and payment history'**
  String get billingPageSubtitle;

  /// No description provided for @billingActiveUntil.
  ///
  /// In en, this message translates to:
  /// **'Active until'**
  String get billingActiveUntil;

  /// No description provided for @billingFreeHint.
  ///
  /// In en, this message translates to:
  /// **'Free tier. Upgrade to Pro to unlock more features.'**
  String get billingFreeHint;

  /// No description provided for @billingRenewOrChange.
  ///
  /// In en, this message translates to:
  /// **'Renew / change'**
  String get billingRenewOrChange;

  /// No description provided for @billingInvoiceHistory.
  ///
  /// In en, this message translates to:
  /// **'Payment history'**
  String get billingInvoiceHistory;

  /// No description provided for @billingLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get billingLoading;

  /// No description provided for @billingEmptyInvoices.
  ///
  /// In en, this message translates to:
  /// **'No payments'**
  String get billingEmptyInvoices;

  /// No description provided for @billingColDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get billingColDate;

  /// No description provided for @billingColDesc.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get billingColDesc;

  /// No description provided for @billingColMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get billingColMethod;

  /// No description provided for @billingColAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get billingColAmount;

  /// No description provided for @billingColStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get billingColStatus;

  /// No description provided for @billingStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get billingStatusPending;

  /// No description provided for @billingStatusWaiting.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get billingStatusWaiting;

  /// No description provided for @billingStatusSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get billingStatusSucceeded;

  /// No description provided for @billingStatusCanceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get billingStatusCanceled;

  /// No description provided for @billingMethodBankCard.
  ///
  /// In en, this message translates to:
  /// **'Bank card'**
  String get billingMethodBankCard;

  /// No description provided for @billingProcessingTitle.
  ///
  /// In en, this message translates to:
  /// **'Processing payment'**
  String get billingProcessingTitle;

  /// No description provided for @billingProcessingDesc.
  ///
  /// In en, this message translates to:
  /// **'Waiting for confirmation from payment system...'**
  String get billingProcessingDesc;

  /// No description provided for @billingSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Pro subscription activated'**
  String get billingSuccessTitle;

  /// No description provided for @billingSuccessDesc.
  ///
  /// In en, this message translates to:
  /// **'Pro is active for: {period}. Redirecting to profile...'**
  String billingSuccessDesc(String period);

  /// No description provided for @billingCanceledTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment canceled'**
  String get billingCanceledTitle;

  /// No description provided for @billingCanceledDesc.
  ///
  /// In en, this message translates to:
  /// **'Payment did not go through. Try again or choose another payment method.'**
  String get billingCanceledDesc;

  /// No description provided for @billingGoToProfile.
  ///
  /// In en, this message translates to:
  /// **'Go to profile'**
  String get billingGoToProfile;

  /// No description provided for @billingTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get billingTryAgain;

  /// No description provided for @billingNoPaymentId.
  ///
  /// In en, this message translates to:
  /// **'Missing payment ID'**
  String get billingNoPaymentId;

  /// No description provided for @billingStatusFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch payment status'**
  String get billingStatusFetchFailed;

  /// No description provided for @upgradeGoPro.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get upgradeGoPro;

  /// No description provided for @upgradeNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get upgradeNotNow;

  /// No description provided for @upgradeClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get upgradeClose;

  /// No description provided for @upgradeCurrentUsage.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get upgradeCurrentUsage;

  /// No description provided for @upgradeCommunityLimitTitle.
  ///
  /// In en, this message translates to:
  /// **'Community limit reached'**
  String get upgradeCommunityLimitTitle;

  /// No description provided for @upgradeCommunityLimitDesc.
  ///
  /// In en, this message translates to:
  /// **'Free tier allows up to 3 communities. Upgrade to Pro to create more.'**
  String get upgradeCommunityLimitDesc;

  /// No description provided for @upgradeCommunityLimitB1.
  ///
  /// In en, this message translates to:
  /// **'Up to 10 communities'**
  String get upgradeCommunityLimitB1;

  /// No description provided for @upgradeCommunityLimitB2.
  ///
  /// In en, this message translates to:
  /// **'Expanded storage'**
  String get upgradeCommunityLimitB2;

  /// No description provided for @upgradeCommunityLimitB3.
  ///
  /// In en, this message translates to:
  /// **'Co-admins and auto-moderation'**
  String get upgradeCommunityLimitB3;

  /// No description provided for @upgradeWhitelabelTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove \"Powered by Domain\"'**
  String get upgradeWhitelabelTitle;

  /// No description provided for @upgradeWhitelabelDesc.
  ///
  /// In en, this message translates to:
  /// **'White-label lets you hide platform branding from your pages.'**
  String get upgradeWhitelabelDesc;

  /// No description provided for @upgradeWhitelabelB1.
  ///
  /// In en, this message translates to:
  /// **'Full branding removal'**
  String get upgradeWhitelabelB1;

  /// No description provided for @upgradeWhitelabelB2.
  ///
  /// In en, this message translates to:
  /// **'Extended customization'**
  String get upgradeWhitelabelB2;

  /// No description provided for @upgradeWhitelabelB3.
  ///
  /// In en, this message translates to:
  /// **'Professional look'**
  String get upgradeWhitelabelB3;

  /// No description provided for @upgradeExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export is a Pro feature'**
  String get upgradeExportTitle;

  /// No description provided for @upgradeExportDesc.
  ///
  /// In en, this message translates to:
  /// **'Export your community data for backup or migration.'**
  String get upgradeExportDesc;

  /// No description provided for @upgradeExportB1.
  ///
  /// In en, this message translates to:
  /// **'Full data export'**
  String get upgradeExportB1;

  /// No description provided for @upgradeExportB2.
  ///
  /// In en, this message translates to:
  /// **'CSV and JSON formats'**
  String get upgradeExportB2;

  /// No description provided for @upgradeExportB3.
  ///
  /// In en, this message translates to:
  /// **'Backup support'**
  String get upgradeExportB3;

  /// No description provided for @upgradeStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage full'**
  String get upgradeStorageTitle;

  /// No description provided for @upgradeStorageDesc.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached the storage limit. Upgrade to Pro for more space.'**
  String get upgradeStorageDesc;

  /// No description provided for @upgradeStorageB1.
  ///
  /// In en, this message translates to:
  /// **'Increased file limit'**
  String get upgradeStorageB1;

  /// No description provided for @upgradeStorageB2.
  ///
  /// In en, this message translates to:
  /// **'Pay-as-you-go for extra space'**
  String get upgradeStorageB2;

  /// No description provided for @upgradeStorageB3.
  ///
  /// In en, this message translates to:
  /// **'Large file support'**
  String get upgradeStorageB3;

  /// No description provided for @upgradeCoadminTitle.
  ///
  /// In en, this message translates to:
  /// **'Need a second moderator?'**
  String get upgradeCoadminTitle;

  /// No description provided for @upgradeCoadminDesc.
  ///
  /// In en, this message translates to:
  /// **'Free tier allows owner-only management. Pro unlocks co-admins.'**
  String get upgradeCoadminDesc;

  /// No description provided for @upgradeCoadminB1.
  ///
  /// In en, this message translates to:
  /// **'Up to 5 moderators'**
  String get upgradeCoadminB1;

  /// No description provided for @upgradeCoadminB2.
  ///
  /// In en, this message translates to:
  /// **'Flexible roles and permissions'**
  String get upgradeCoadminB2;

  /// No description provided for @upgradeCoadminB3.
  ///
  /// In en, this message translates to:
  /// **'Team management'**
  String get upgradeCoadminB3;

  /// No description provided for @upgradeModerationTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-moderation is a Pro feature'**
  String get upgradeModerationTitle;

  /// No description provided for @upgradeModerationDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatic banned-word filtering is available on Pro.'**
  String get upgradeModerationDesc;

  /// No description provided for @upgradeModerationB1.
  ///
  /// In en, this message translates to:
  /// **'Banned words filter'**
  String get upgradeModerationB1;

  /// No description provided for @upgradeModerationB2.
  ///
  /// In en, this message translates to:
  /// **'Automatic removal'**
  String get upgradeModerationB2;

  /// No description provided for @upgradeModerationB3.
  ///
  /// In en, this message translates to:
  /// **'Customizable lists'**
  String get upgradeModerationB3;

  /// No description provided for @upgradeWebappTitle.
  ///
  /// In en, this message translates to:
  /// **'Web mini-apps — Pro feature'**
  String get upgradeWebappTitle;

  /// No description provided for @upgradeWebappDesc.
  ///
  /// In en, this message translates to:
  /// **'Lua scripts with HTTP API are only available on Pro.'**
  String get upgradeWebappDesc;

  /// No description provided for @upgradeWebappB1.
  ///
  /// In en, this message translates to:
  /// **'Lua sandbox'**
  String get upgradeWebappB1;

  /// No description provided for @upgradeWebappB2.
  ///
  /// In en, this message translates to:
  /// **'HTTP API for scripts'**
  String get upgradeWebappB2;

  /// No description provided for @upgradeWebappB3.
  ///
  /// In en, this message translates to:
  /// **'Interactive sections'**
  String get upgradeWebappB3;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
