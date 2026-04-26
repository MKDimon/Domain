// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'Domain';

  @override
  String get navExplore => 'Обзор';

  @override
  String get navLogin => 'Войти';

  @override
  String get navRegister => 'Регистрация';

  @override
  String get navLogout => 'Выйти';

  @override
  String get navProfile => 'Профиль';

  @override
  String get navAdmin => 'Админ';

  @override
  String get navHome => 'Главная';

  @override
  String get navChat => 'Чат';

  @override
  String get navMenu => 'Меню';

  @override
  String get navBack => 'Назад';

  @override
  String get authLoginTitle => 'Вход';

  @override
  String get authLoginSubtitle => 'Войдите в свой аккаунт';

  @override
  String get authRegisterTitle => 'Регистрация';

  @override
  String get authRegisterSubtitle => 'Создайте аккаунт';

  @override
  String get authUsername => 'Имя пользователя';

  @override
  String get authUsernameOrEmail => 'Имя пользователя или email';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Пароль';

  @override
  String get authConfirmPassword => 'Подтверждение пароля';

  @override
  String get authFillAllFields => 'Заполните все поля';

  @override
  String get authLoginFailed => 'Ошибка входа';

  @override
  String get authRegistrationFailed => 'Ошибка регистрации';

  @override
  String get authPasswordsDontMatch => 'Пароли не совпадают';

  @override
  String get authPasswordTooShort => 'Пароль должен быть не менее 6 символов';

  @override
  String get authPasswordMinLength => '6+ символов';

  @override
  String get authPasswordUppercase => 'Заглавная буква';

  @override
  String get authNoAccount => 'Нет аккаунта?';

  @override
  String get authHasAccount => 'Уже есть аккаунт?';

  @override
  String get authSignIn => 'Войти';

  @override
  String get authRegister => 'Зарегистрироваться';

  @override
  String get authAgreeTerms =>
      'Я принимаю Пользовательское соглашение и Политику конфиденциальности';

  @override
  String get heroTitle => 'Создай своё сообщество';

  @override
  String get heroSubtitle =>
      'Создавайте страницы, общайтесь, делитесь знаниями — всё в одном месте';

  @override
  String get heroSearch => 'Поиск сообществ...';

  @override
  String get popularCommunities => 'Популярные сообщества';

  @override
  String get popularArticles => 'Популярные статьи';

  @override
  String get viewAll => 'Все →';

  @override
  String get categories => 'Категории';

  @override
  String get ctaTitle => 'Начни своё сообщество';

  @override
  String get ctaSubtitle =>
      'Создавайте страницы, управляйте участниками, стройте базу знаний';

  @override
  String get ctaFeaturePages => 'Страницы';

  @override
  String get ctaFeatureChat => 'Чат';

  @override
  String get ctaFeaturePlugins => 'Плагины';

  @override
  String get ctaFeaturePagesDesc => 'Конструктор страниц\nс плагинами';

  @override
  String get ctaFeatureChatDesc => 'Общение\nв реальном времени';

  @override
  String get ctaFeaturePluginsDesc => 'Вики, опросы, бронирование\nи другое';

  @override
  String get ctaButton => 'Создать сообщество';

  @override
  String get ctaFree => 'Бесплатно до 3 сообществ';

  @override
  String footerCopyright(String year) {
    return 'Domain © $year';
  }

  @override
  String communitiesCount(int count) {
    return '$count сообществ';
  }

  @override
  String get communitiesLabel => 'сообществ';

  @override
  String membersCount(int count) {
    return '$count';
  }

  @override
  String get members => 'участников';

  @override
  String get pages => 'страниц';

  @override
  String get pagesTitle => 'Страницы';

  @override
  String get views => 'просмотров';

  @override
  String get exploreBack => '← Назад';

  @override
  String get exploreTitle => 'Обзор';

  @override
  String get exploreCreate => 'Создать';

  @override
  String get exploreNoCommunities => 'Сообщества не найдены';

  @override
  String get exploreSearch => 'Поиск сообществ...';

  @override
  String get communityNotFound => 'Не найдено';

  @override
  String get communityBackToMain => '← На главную';

  @override
  String get communityHome => 'Главная';

  @override
  String get communityNoPages => 'В этом сообществе пока нет страниц.';

  @override
  String get communityLoadFailed => 'Не удалось загрузить сообщество';

  @override
  String get createCommunityTitle => 'Создать сообщество';

  @override
  String get createCommunityName => 'Название';

  @override
  String get createCommunityNamePlaceholder => 'Мое сообщество';

  @override
  String get createCommunitySlug => 'Slug';

  @override
  String get createCommunitySlugPlaceholder => 'moe-soobschestvo';

  @override
  String get createCommunityDescription => 'Описание (необязательно)';

  @override
  String get createCommunityDescriptionPlaceholder => 'О чем ваше сообщество?';

  @override
  String get createCommunityVisibility => 'Видимость';

  @override
  String get createCommunityPublic => 'Открытое сообщество';

  @override
  String get createCommunityPrivate => 'Закрытое сообщество';

  @override
  String get createCommunityPublicHint =>
      'Сообщество видно всем и любой может вступить';

  @override
  String get createCommunityPrivateHint =>
      'Сообщество видно только участникам. Требуется приглашение для вступления.';

  @override
  String get createCommunityCreating => 'Создание...';

  @override
  String get createCommunityNameSlugRequired => 'Название и slug обязательны';

  @override
  String get createCommunityFailed => 'Не удалось создать сообщество';

  @override
  String get createCommunityButton => 'Создать сообщество';

  @override
  String get pageViewBackToCommunity => 'Назад к сообществу';

  @override
  String get pageViewLoadFailed => 'Не удалось загрузить страницу';

  @override
  String get pageViewNoSections => 'На этой странице пока нет секций.';

  @override
  String get chatTypeMessage => 'Введите сообщение...';

  @override
  String get chatNoMessages => 'Сообщений пока нет. Начните общение!';

  @override
  String get chatDeleteConfirm => 'Удалить это сообщение?';

  @override
  String get chatReply => 'Ответить';

  @override
  String get chatDelete => 'Удалить';

  @override
  String get chatReplyingTo => 'Ответ на';

  @override
  String get chatCancelReply => 'Отменить ответ';

  @override
  String get chatSend => 'Отправить';

  @override
  String get chatLoginToChat => 'Войдите, чтобы участвовать';

  @override
  String get chatMissedCallOut => 'Не ответили';

  @override
  String get chatMissedCallIn => 'Пропущенный звонок от';

  @override
  String get chatCallDeclined => 'Звонок отклонён';

  @override
  String get chatCallCancelled => 'Вы отменили звонок';

  @override
  String get chatCallYouDeclined => 'Вы отклонили звонок от';

  @override
  String get chatVoiceCall => 'Голосовой звонок';

  @override
  String get chatVideoCall => 'Видеозвонок';

  @override
  String get chatScrollToBottom => 'К последним сообщениям';

  @override
  String get chatJumpToDate => 'Перейти к дате';

  @override
  String get chatTypingSingle => 'печатает...';

  @override
  String chatTypingOne(String name) {
    return '$name печатает...';
  }

  @override
  String chatTypingTwo(String name1, String name2) {
    return '$name1 и $name2 печатают...';
  }

  @override
  String chatTypingMany(String name1, String name2, int count) {
    return '$name1, $name2 и ещё $count печатают...';
  }

  @override
  String get commonAll => 'Все';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonConfirm => 'Подтвердить';

  @override
  String get commonClose => 'Закрыть';

  @override
  String get commonMore => 'Ещё';

  @override
  String get commonLoading => 'Загрузка';

  @override
  String get commonRetry => 'Повторить';

  @override
  String get themeLight => 'Светлая тема';

  @override
  String get themeDark => 'Тёмная тема';

  @override
  String get communityJoin => 'Вступить';

  @override
  String get communityLeave => 'Покинуть';

  @override
  String get communityMember => 'Участник';

  @override
  String get communityOwner => 'Владелец';

  @override
  String get communityModerator => 'Модератор';

  @override
  String get communitySections => 'Секции';

  @override
  String get communityPopularPages => 'Популярные страницы';

  @override
  String get communityRecentChanges => 'Недавние изменения';

  @override
  String get communitySettings => 'Настройки';

  @override
  String get communityMembers => 'Участники';

  @override
  String get communitySearch => 'Поиск в сообществе...';

  @override
  String get communityVoice => 'Голос';

  @override
  String get communityFavorites => 'Избранное';

  @override
  String get communityMessages => 'Сообщения';

  @override
  String get communityNotifications => 'Уведомления';

  @override
  String get communityEditHomePage => 'Редактировать главную';

  @override
  String get communityReport => 'Пожаловаться';

  @override
  String get reportTitle => 'Пожаловаться';

  @override
  String get reportSubtitle =>
      'Жалоба будет рассмотрена модераторами платформы в течение 24 часов.';

  @override
  String get reportTarget => 'На что жалоба';

  @override
  String get reportCommentLabel => 'Комментарий (необязательно)';

  @override
  String get reportCommentHint => 'Опишите ситуацию подробнее...';

  @override
  String get reportSubmit => 'Отправить';

  @override
  String get reportSending => 'Отправка...';

  @override
  String get reportCancel => 'Отмена';

  @override
  String get reportSentTitle => 'Жалоба отправлена';

  @override
  String get reportSentMessage =>
      'Мы рассмотрим вашу жалобу в течение 24 часов.';

  @override
  String get reportDone => 'Готово';

  @override
  String get reportFailed => 'Не удалось отправить жалобу';

  @override
  String get reportReasonSpam => 'Спам или реклама';

  @override
  String get reportReasonFraud => 'Мошенничество / фишинг';

  @override
  String get reportReasonInsult => 'Оскорбления / мат';

  @override
  String get reportReasonExtremism => 'Экстремизм, разжигание ненависти';

  @override
  String get reportReasonAdult => 'Контент 18+';

  @override
  String get reportReasonCopyright => 'Нарушение авторских прав';

  @override
  String get reportReasonThreat => 'Угрозы, призывы к насилию';

  @override
  String get reportReasonOther => 'Другое';

  @override
  String get voiceChannelEmpty => 'Канал пуст';

  @override
  String get voiceChannelEmptyHint => 'Нажмите «Подключиться» внизу';

  @override
  String get voiceJoin => 'Подключиться';

  @override
  String get voiceLeave => 'Отключиться';

  @override
  String get voiceMute => 'Выключить микрофон';

  @override
  String get voiceUnmute => 'Включить микрофон';

  @override
  String get voiceSettings => 'Настройки звука';

  @override
  String voiceParticipants(Object count) {
    return '$count участн.';
  }

  @override
  String get voiceConnecting => 'Подключение...';

  @override
  String get voiceMicError => 'Не удалось получить доступ к микрофону';

  @override
  String get voiceConnectionGood => 'Соединение хорошее';

  @override
  String get voiceConnectionOk => 'Соединение среднее';

  @override
  String get voiceConnectionBad => 'Плохое соединение';

  @override
  String get voicePttHint => 'Удерживайте эту клавишу для передачи голоса';

  @override
  String get voiceActivationVad => 'Голосовая';

  @override
  String get voiceActivationPtt => 'Клавиша (PTT)';

  @override
  String get voiceActivationMode => 'РЕЖИМ АКТИВАЦИИ';

  @override
  String get voiceAudioProcessing => 'ОБРАБОТКА ЗВУКА';

  @override
  String get voiceEchoCancellation => 'Эхоподавление';

  @override
  String get voiceNoiseSuppression => 'Шумоподавление';

  @override
  String get voiceVolume => 'ГРОМКОСТЬ';

  @override
  String get voiceSfx => 'Звуковые эффекты';

  @override
  String get voicePttKey => 'Клавиша PTT';

  @override
  String get voicePttRecording => 'Нажмите клавишу...';

  @override
  String get voiceSettingsTitle => 'Настройки звука';

  @override
  String get voiceOnline => 'Онлайн';

  @override
  String get voiceFloatingTitle => 'Голосовой кан��л';

  @override
  String get voiceDevices => 'УСТРОЙСТВА';

  @override
  String get voiceMicrophone => 'Микрофон';

  @override
  String get voiceSpeaker => 'Динамик';

  @override
  String get voiceTestMic => 'Проверить микрофон';

  @override
  String get voiceStopTest => 'Остановить';

  @override
  String get voiceTestMicHint =>
      'Говорите в микрофон — полоса должна двигаться';

  @override
  String get voiceInputVolume => 'Микрофон';

  @override
  String get voiceOutputVolume => 'Динамик';

  @override
  String get voiceNoiseFilter => 'Шумоподавление';

  @override
  String get voiceNfOff => 'Отключено';

  @override
  String get voiceNfBuiltin => 'Встроенное (WebRTC NS)';

  @override
  String get voiceNfRnnoise => 'RNNoise (AI) — скоро';

  @override
  String get voiceNfHintOff => 'Шумоподавление отключено';

  @override
  String get voiceNfHintBuiltin =>
      'Встроенное WebRTC NS — базовое подавление фонового шума';

  @override
  String get voiceEcHint => 'Подавляет эхо от динамиков';

  @override
  String get voiceAutoVad => 'Автопорог';

  @override
  String get voiceAutoVadHint =>
      'Автоматически подстраивается под уровень шума';

  @override
  String get voiceSensitivity => 'Чувствительность';

  @override
  String get voiceSensitivityHint =>
      'Ниже — больше ловит шёпот, выше — только громкий голос';

  @override
  String get voiceReset => 'Сбросить';

  @override
  String get voiceDone => 'Готово';

  @override
  String get voiceMuteHotkey => 'ГОРЯЧАЯ КЛАВИША МЬЮТА';

  @override
  String get voiceMuteKeyNotSet => 'Не задана';

  @override
  String get voiceMuteKeyHint => 'Работает даже когда окно свёрнуто';

  @override
  String get voiceMuteKeyRecording => 'Нажмите комбинацию...';

  @override
  String get inboxConversations => 'Беседы';

  @override
  String get inboxNoConversations => 'Нет бесед';

  @override
  String get inboxStartConversation => 'Начните беседу';

  @override
  String get inboxSelectConversation => 'Выберите ��еседу';

  @override
  String get inboxJustNow => 'только что';

  @override
  String get chatSearchMessages => 'Поиск сообщений...';

  @override
  String get chatNoSearchResults => 'Ничего не найдено';

  @override
  String get chatSearchHint => 'Введите запрос...';

  @override
  String get chatToday => 'Сегодня';

  @override
  String get chatYesterday => 'Вчера';

  @override
  String get pricingLoading => 'Загрузка...';

  @override
  String get pricingTitle => 'Тарифы';

  @override
  String get pricingSubtitle =>
      'Выберите план, который подходит вашим сообществам';

  @override
  String get pricingMonthly => 'Ежемесячно';

  @override
  String get pricingYearly => 'Ежегодно';

  @override
  String get pricingMonth => 'мес';

  @override
  String get pricingForever => 'навсегда';

  @override
  String get pricingRecommended => 'Рекомендуем';

  @override
  String pricingTrialTitle(int days) {
    return 'Попробуйте Pro бесплатно на $days дней';
  }

  @override
  String get pricingTrialHint =>
      'Полный доступ ко всем Pro-функциям без оплаты';

  @override
  String get pricingStartTrial => 'Начать пробный период';

  @override
  String get pricingTrialAvailableSoon => 'Пробный период скоро будет доступен';

  @override
  String get pricingStartFree => 'Начать бесплатно';

  @override
  String get pricingUpgradePro => 'Перейти на Pro';

  @override
  String get pricingRedirecting => 'Переход к оплате...';

  @override
  String get pricingPayFailed => 'Ошибка оплаты';

  @override
  String get pricingFreePriceSub => 'Бесплатно, без ограничения по времени';

  @override
  String get pricingMonthlyBillingSub => 'Оплата ежемесячно';

  @override
  String pricingYearlyBillingSub(int total, int savings) {
    return '$total₽/год, экономия $savings₽';
  }

  @override
  String get pricingFreeTagline => 'Всё необходимое для старта';

  @override
  String pricingFreeCommunities(int n) {
    return 'До $n сообщест��';
  }

  @override
  String get pricingFreeStorage => 'Базовое хранилище файлов';

  @override
  String get pricingFreePlugins => 'Все основные плагины секций';

  @override
  String get pricingFreeAnalytics => 'Базовая аналитика посещений';

  @override
  String get pricingFreeAdmins => 'Только владелец управляет';

  @override
  String get pricingProTagline => 'Полный контроль и масштабир��вание';

  @override
  String get pricingProIncludesFree => 'Всё из Free, пл��с:';

  @override
  String pricingProCommunities(int n) {
    return 'До $n сообществ';
  }

  @override
  String get pricingProStorage => 'Расширенное хранилище + оплата за объём';

  @override
  String get pricingProAnalytics => 'Продвинутая аналитика и экспорт';

  @override
  String pricingProModerators(int n) {
    return 'До $n со-админов/мод��раторов';
  }

  @override
  String get pricingProAutomod => 'Автомодерация запрещённых слов';

  @override
  String get pricingProExport => 'Экспорт данных сообщества';

  @override
  String get pricingProWhitelabel => 'White-label: скрыть бренд��нг';

  @override
  String get pricingProNoAds => 'Без рекламного виджета';

  @override
  String get pricingFaqTitle => 'Частые вопросы';

  @override
  String get pricingFaqRefundQ => 'Можно ли вернуть деньги?';

  @override
  String pricingFaqRefundA(int days) {
    return 'Да, в течение $days дней после оплаты — напишите в поддержку.';
  }

  @override
  String get pricingFaqCancelQ => 'Как отменить подписк��?';

  @override
  String get pricingFaqCancelA =>
      'В разделе «Оплата» в профиле. Подписка останется активной до конца периода.';

  @override
  String get pricingFaqRenewQ => 'Подписка продлевается автоматически?';

  @override
  String get pricingFaqRenewA =>
      'Нет, автопродление отсутствует. Вы продлеваете подписку вручную.';

  @override
  String get pricingFaqDowngradeQ => 'Что будет при переходе на Free?';

  @override
  String get pricingFaqDowngradeA =>
      'Ваши сообщества останутся, но Pro-функции будут ограничены.';

  @override
  String get pricingOfferNote => 'Условия и подробности — в ';

  @override
  String get pricingOfferLink => 'публичной оферте';

  @override
  String get billingTierFree => 'Free';

  @override
  String get billingTierPro => 'Pro';

  @override
  String get billingPageTitle => 'Оплата и подписка';

  @override
  String get billingPageSubtitle =>
      'Управление тарифным планом и историей платежей';

  @override
  String get billingActiveUntil => 'Активен до';

  @override
  String get billingFreeHint =>
      'Бесплатный тариф. Обновитесь до Pro для доступа к дополнительным функциям.';

  @override
  String get billingRenewOrChange => 'Продлить / изменить';

  @override
  String get billingInvoiceHistory => 'История платежей';

  @override
  String get billingLoading => 'Загрузка...';

  @override
  String get billingEmptyInvoices => 'Нет платежей';

  @override
  String get billingColDate => 'Дата';

  @override
  String get billingColDesc => 'Описание';

  @override
  String get billingColMethod => 'Способ';

  @override
  String get billingColAmount => 'Сумма';

  @override
  String get billingColStatus => 'Статус';

  @override
  String get billingStatusPending => 'Ожидание';

  @override
  String get billingStatusWaiting => 'Обработка';

  @override
  String get billingStatusSucceeded => 'Оплачен';

  @override
  String get billingStatusCanceled => 'Отменён';

  @override
  String get billingMethodBankCard => 'Банковская карта';

  @override
  String get billingProcessingTitle => 'Обработка платежа';

  @override
  String get billingProcessingDesc =>
      'Ожидание подтверждения от платёжной системы...';

  @override
  String get billingSuccessTitle => 'Pro-подписка активирована';

  @override
  String billingSuccessDesc(String period) {
    return 'Pro активен на период: $period. Переход в профиль...';
  }

  @override
  String get billingCanceledTitle => 'Платёж от��енён';

  @override
  String get billingCanceledDesc =>
      'Оплата не прошла. Попробуйте ещё раз или выберите другой способ оплаты.';

  @override
  String get billingGoToProfile => 'В профиль';

  @override
  String get billingTryAgain => 'Попробовать снова';

  @override
  String get billingNoPaymentId => 'Отсутствует ID платежа';

  @override
  String get billingStatusFetchFailed => 'Не удалось получить статус платежа';

  @override
  String get upgradeGoPro => 'Перейти на Pro';

  @override
  String get upgradeNotNow => 'Не сейчас';

  @override
  String get upgradeClose => 'Закрыть';

  @override
  String get upgradeCurrentUsage => 'Использовано';

  @override
  String get upgradeCommunityLimitTitle => 'Лимит сообществ достигнут';

  @override
  String get upgradeCommunityLimitDesc =>
      'На бесплатном тарифе доступно до 3 сообществ. Перейдите на Pro, чтобы создавать больше.';

  @override
  String get upgradeCommunityLimitB1 => 'До 10 сообществ';

  @override
  String get upgradeCommunityLimitB2 => 'Расширенное хранилище';

  @override
  String get upgradeCommunityLimitB3 => 'Со-админы и автомодерация';

  @override
  String get upgradeWhitelabelTitle => 'Убрать «Powered by Domain»';

  @override
  String get upgradeWhitelabelDesc =>
      'White-label позволяет скрыть брендинг платформы на ваших страниц��х.';

  @override
  String get upgradeWhitelabelB1 => 'Полное удаление брендинга';

  @override
  String get upgradeWhitelabelB2 => 'Расширенная кастомизация';

  @override
  String get upgradeWhitelabelB3 => 'Профессиональный вид';

  @override
  String get upgradeExportTitle => 'Экспорт — функция Pro';

  @override
  String get upgradeExportDesc =>
      'Экспортируйте данные сообщества для резервного копирования или миграции.';

  @override
  String get upgradeExportB1 => 'Полный экспорт данных';

  @override
  String get upgradeExportB2 => 'Форматы CSV и JSON';

  @override
  String get upgradeExportB3 => 'Резервное копирование';

  @override
  String get upgradeStorageTitle => 'Хранилище заполнено';

  @override
  String get upgradeStorageDesc =>
      'Вы достигли лимита хранилища. Перейдите на Pro для увеличения объёма.';

  @override
  String get upgradeStorageB1 => 'Увеличенный лимит файлов';

  @override
  String get upgradeStorageB2 => 'Оплата за дополнительный объё��';

  @override
  String get upgradeStorageB3 => 'Поддержка больших файлов';

  @override
  String get upgradeCoadminTitle => 'Нужен второй модератор?';

  @override
  String get upgradeCoadminDesc =>
      'На бесплатном тарифе управлять может только владелец. Pro открывает со-админов.';

  @override
  String get upgradeCoadminB1 => 'До 5 модераторов';

  @override
  String get upgradeCoadminB2 => 'Гибкие роли и права';

  @override
  String get upgradeCoadminB3 => 'Ком��ндное управление';

  @override
  String get upgradeModerationTitle => 'Автомодерация — функция Pro';

  @override
  String get upgradeModerationDesc =>
      'Автоматическая фильтрация запрещённых слов доступна на Pro.';

  @override
  String get upgradeModerationB1 => 'Фильтр запрещённых слов';

  @override
  String get upgradeModerationB2 => 'Автоматическое удаление';

  @override
  String get upgradeModerationB3 => 'Настраиваемые списки';

  @override
  String get upgradeWebappTitle => 'Веб-приложения — функция Pro';

  @override
  String get upgradeWebappDesc =>
      'Lua-скрипты с HTTP API доступны только на Pro.';

  @override
  String get upgradeWebappB1 => 'Lua-песочница';

  @override
  String get upgradeWebappB2 => 'HTTP API для скриптов';

  @override
  String get upgradeWebappB3 => 'Интерактивные секции';
}
