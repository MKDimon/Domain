import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../shell/app_shell.dart';
import '../shell/shell_state.dart';
// NavHistory and isNavHistoryNav from shell_state
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/main/screens/main_screen.dart';
import '../../features/main/screens/explore_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/public_profile_screen.dart';
import '../../features/community/screens/community_screen.dart';
import '../../features/community/screens/create_community_screen.dart';
import '../../features/community/screens/invite_join_screen.dart';
import '../../features/admin/screens/admin_screen.dart';
import '../../features/community/screens/community_settings_screen.dart';
import '../../features/editor/screens/page_editor_screen.dart';
import '../../features/messages/screens/messages_screen.dart';
import '../../features/feedback/screens/feedback_screen.dart';
import '../../features/legal/screens/legal_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/billing/screens/pricing_screen.dart';
import '../../features/billing/screens/billing_screen.dart';
import '../../features/billing/screens/billing_success_screen.dart';
import '../../features/legal/screens/legal_requisites_screen.dart';
import '../../features/auth/screens/verify_email_screen.dart';
import '../../features/auth/screens/email_sent_screen.dart';

CustomTransitionPage<void> _fade(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 120),
    reverseTransitionDuration: const Duration(milliseconds: 80),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    if (!isNavHistoryNav) {
      NavHistory().push(state.uri.toString());
    }
    isNavHistoryNav = false;
    return null;
  },
  routes: [
    // Auth routes — no shell
    GoRoute(path: '/login', name: 'login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/register', name: 'register', builder: (context, state) => const RegisterScreen()),
    GoRoute(path: '/verify-email', name: 'verify-email', builder: (context, state) => VerifyEmailScreen(token: state.uri.queryParameters['token'])),
    GoRoute(path: '/email-sent', name: 'email-sent', builder: (context, state) => EmailSentScreen(email: state.uri.queryParameters['email'])),

    // Shell routes — persistent header
    ShellRoute(
      builder: (context, state, child) {
        final isCommunityRoute = state.uri.path.startsWith('/community/');
        return Consumer(builder: (ctx, ref, _) {
          final comm = isCommunityRoute ? ref.watch(shellCommunityProvider) : null;
          return AppShell(
            communitySlug: comm?.slug,
            communityName: comm?.name,
            communityColor: comm?.color,
            child: child,
          );
        });
      },
      routes: [
        GoRoute(path: '/', name: 'main', pageBuilder: (context, state) => _fade(state, const MainScreen())),
        GoRoute(path: '/profile', name: 'profile', pageBuilder: (context, state) => _fade(state, const ProfileScreen())),
        GoRoute(path: '/explore', name: 'explore', pageBuilder: (context, state) => _fade(state, ExploreScreen(initialCategory: state.uri.queryParameters['category']))),
        GoRoute(path: '/create', name: 'create-community', pageBuilder: (context, state) => _fade(state, const CreateCommunityScreen())),
        GoRoute(path: '/invite/:token', name: 'invite-join', pageBuilder: (context, state) => _fade(state, InviteJoinScreen(token: state.pathParameters['token']!))),
        GoRoute(path: '/messages', name: 'messages', pageBuilder: (context, state) => _fade(state, MessagesScreen(openWithUserId: int.tryParse(state.uri.queryParameters['open'] ?? '')))),
        GoRoute(path: '/notifications', name: 'notifications', pageBuilder: (context, state) => _fade(state, const NotificationsScreen())),
        GoRoute(path: '/user/:id', name: 'user-profile', pageBuilder: (context, state) => _fade(state, PublicProfileScreen(userId: int.tryParse(state.pathParameters['id'] ?? '')))),
        GoRoute(path: '/@:username', name: 'user-profile-by-name', pageBuilder: (context, state) => _fade(state, PublicProfileScreen(username: state.pathParameters['username']))),
        GoRoute(path: '/admin', name: 'admin', pageBuilder: (context, state) => _fade(state, const AdminScreen())),
        GoRoute(path: '/pricing', name: 'pricing', pageBuilder: (context, state) => _fade(state, const PricingScreen())),
        GoRoute(path: '/billing', name: 'billing', pageBuilder: (context, state) => _fade(state, const BillingScreen())),
        GoRoute(path: '/billing/success', name: 'billing-success', pageBuilder: (context, state) => _fade(state, BillingSuccessScreen(paymentId: state.uri.queryParameters['payment_id']))),
        GoRoute(path: '/feedback', name: 'feedback', pageBuilder: (context, state) => _fade(state, const FeedbackScreen())),
        GoRoute(path: '/legal/requisites', name: 'legal-requisites', pageBuilder: (context, state) => _fade(state, const LegalRequisitesScreen())),
        GoRoute(path: '/legal/:type', name: 'legal', pageBuilder: (context, state) => _fade(state, LegalScreen(type: state.pathParameters['type'] ?? 'terms'))),
        GoRoute(path: '/community/:slug', name: 'community', pageBuilder: (context, state) => _fade(state, CommunityScreen(slug: state.pathParameters['slug']!))),
        GoRoute(path: '/community/:slug/page/:pageId', name: 'page-view', pageBuilder: (context, state) => _fade(state, CommunityScreen(
          slug: state.pathParameters['slug']!, pageId: int.parse(state.pathParameters['pageId']!),
        ))),
        GoRoute(path: '/community/:slug/settings', name: 'community-settings', pageBuilder: (context, state) => _fade(state, CommunitySettingsScreen(slug: state.pathParameters['slug']!))),
        GoRoute(path: '/community/:slug/page/:pageId/edit', name: 'page-edit', pageBuilder: (context, state) => _fade(state, PageEditorScreen(
          communitySlug: state.pathParameters['slug']!, pageId: int.parse(state.pathParameters['pageId']!),
        ))),
      ],
    ),
  ],
);
