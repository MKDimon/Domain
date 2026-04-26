const sectionDefaults = <String, Map<String, dynamic>>{
  'content': {
    'config': {'title': 'Content', 'visible': true, 'editable': true, 'editorMode': 'blocks'},
    'data': {'blocks': []},
  },
  'chat': {
    'config': {'title': 'Chat', 'visible': true, 'moderated': false, 'max_length': 500, 'chat_height_pct': 30},
    'data': {'settings': {'max_length': 500, 'moderated': false}},
  },
  'products': {
    'config': {'title': 'Products', 'visible': true, 'layout': 'grid', 'items_per_page': 12},
    'data': {'items': [], 'filters': {'categories': []}},
  },
  'wiki': {
    'config': {'title': 'Wiki', 'visible': true, 'editable': true},
    'data': {'articles': []},
  },
  'script': {
    'config': {'title': 'Script', 'visible': true},
    'data': {'code': '-- Script\nui.heading("Hello!", 2)\nui.text("Example")\n', 'visual_blocks': {}, 'editor_mode': 'text'},
  },
  'booking': {
    'config': {'title': 'Booking', 'visible': true, 'slot_duration': 30, 'work_start': '09:00', 'work_end': '18:00'},
    'data': {'specialists': []},
  },
  'announcements': {
    'config': {'title': 'Announcements', 'visible': true, 'allow_priority': true, 'allow_pinning': true},
    'data': {},
  },
  'polls': {
    'config': {'title': 'Poll', 'visible': true, 'allow_multiple': false, 'show_results': true},
    'data': {'question': '', 'options': []},
  },
  'calendar': {
    'config': {'title': 'Calendar', 'visible': true, 'week_start': 'monday', 'default_view': 'month'},
    'data': {},
  },
  'quiz': {
    'config': {'title': 'Quiz', 'visible': true},
    'data': {'cards': [], 'settings': {'shuffleOnStart': true, 'showProgress': true, 'modes': {'flashcards': {'enabled': true}, 'test': {'enabled': true}, 'type': {'enabled': true}}}},
  },
  'popular-pages': {
    'config': {'title': '', 'limit': 5, 'show_views': true},
    'data': {},
  },
  'recent-updates': {
    'config': {'title': '', 'limit': 5},
    'data': {},
  },
  'community-header': {
    'config': {'title': 'Header', 'visible': true},
    'data': {},
  },
  'navigation': {
    'config': {'title': 'Navigation', 'visible': true},
    'data': {},
  },
  'columns': {
    'config': {'column_count': 2},
    'data': {'columns': [
      {'section_type': 'popular-pages', 'config': {'limit': 5, 'show_views': true}, 'data': {}},
      {'section_type': 'recent-updates', 'config': {'limit': 5}, 'data': {}},
    ]},
  },
};

const mainPageOnlySections = {'community-header', 'navigation', 'popular-pages', 'recent-updates'};

const sectionTypeLabels = <String, String>{
  'content': 'Контент',
  'chat': 'Чат',
  'products': 'Товары',
  'wiki': 'Вики',
  'script': 'Скрипт',
  'booking': 'Бронирование',
  'announcements': 'Объявления',
  'polls': 'Опрос',
  'calendar': 'Календарь',
  'quiz': 'Квиз',
  'popular-pages': 'Популярные',
  'recent-updates': 'Обновления',
  'community-header': 'Шапка',
  'navigation': 'Навигация',
  'columns': 'Колонки',
};

const sectionTypeIcons = <String, int>{
  'content': 0xe14f, // Icons.article_outlined
  'chat': 0xe15a, // Icons.chat_outlined
  'products': 0xf37b, // Icons.storefront_outlined
  'wiki': 0xe3e7, // Icons.menu_book_outlined
  'script': 0xe86f, // Icons.code
  'booking': 0xef47, // Icons.calendar_month_outlined
  'announcements': 0xef48, // Icons.campaign_outlined
  'polls': 0xf0b8, // Icons.poll_outlined
  'calendar': 0xe614, // Icons.event_outlined
  'quiz': 0xef67, // Icons.quiz_outlined
  'popular-pages': 0xe255, // Icons.star_outline
  'recent-updates': 0xe52f, // Icons.update
  'community-header': 0xf57b, // Icons.web_outlined
  'navigation': 0xe3e0, // Icons.grid_view
  'columns': 0xe949, // Icons.view_column_outlined
};

const sectionTypeTextIcons = <String, String>{
  'content': 'Aa',
  'chat': '#',
  'products': '\$',
  'wiki': 'W',
  'script': '{;}',
  'booking': '📅',
  'announcements': '📢',
  'polls': '📊',
  'calendar': '🗓️',
  'quiz': '?!',
  'popular-pages': '★',
  'recent-updates': '⏱',
  'community-header': '🏠',
  'navigation': '📑',
  'columns': '▥',
};

const sectionTypeDescriptions = <String, String>{
  'content': 'Текст, изображения, код',
  'chat': 'Обсуждение',
  'products': 'Каталог товаров',
  'wiki': 'Wiki-статья',
  'script': 'Lua-скрипт (интерактивный)',
  'booking': 'Система бронирования',
  'announcements': 'Новости и обновления',
  'polls': 'Голосование',
  'calendar': 'Календарь событий',
  'quiz': 'Карточки, тесты, ввод ответа',
  'popular-pages': 'Виджет популярных страниц',
  'recent-updates': 'Виджет последних обновлений',
  'community-header': 'Баннер, аватар, название, описание и кнопки',
  'navigation': 'Компактный список страниц сообщества',
  'columns': 'Расположение секций рядом',
};

const sectionContentMinWidth = <String, double>{
  'content': 120,
  'chat': 120,
  'products': 320,
  'wiki': 172,
  'script': 106,
  'booking': 84,
  'announcements': 180,
  'polls': 86,
  'calendar': 148,
  'quiz': 126,
  'popular-pages': 120,
  'recent-updates': 120,
  'community-header': 200,
  'navigation': 112,
  'columns': 0,
};

const blockDefaults = <String, Map<String, dynamic>>{
  'heading': {'type': 'heading', 'level': 2, 'text': ''},
  'paragraph': {'type': 'paragraph', 'text': ''},
  'image': {'type': 'image', 'url': '', 'caption': ''},
  'divider': {'type': 'divider'},
  'callout': {'type': 'callout', 'style': 'info', 'text': ''},
  'code': {'type': 'code', 'language': '', 'content': ''},
  'list': {'type': 'list', 'style': 'unordered', 'items': ['']},
  'quote': {'type': 'quote', 'text': '', 'author': ''},
  'columns': {'type': 'columns', 'columns': [{'blocks': []}, {'blocks': []}]},
  'accordion': {'type': 'accordion', 'items': [{'title': '', 'content': ''}], 'allowMultipleOpen': false},
  'table': {'type': 'table', 'headers': ['', '', ''], 'rows': [['', '', '']], 'striped': false},
  'tabs': {'type': 'tabs', 'tabs': [{'label': '', 'blocks': []}, {'label': '', 'blocks': []}]},
  'embed': {'type': 'embed', 'url': '', 'provider': ''},
  'gallery': {'type': 'gallery', 'images': [], 'columns': 3},
  'button': {'type': 'button', 'text': '', 'url': '', 'style': 'primary', 'align': 'center'},
  'product-card': {'type': 'product-card', 'items': [{'name': '', 'price': '', 'image': '', 'description': '', 'tags': []}], 'layout': 'grid'},
};

const blockTypeLabels = <String, String>{
  'heading': 'Заголовок',
  'paragraph': 'Параграф',
  'image': 'Изображение',
  'divider': 'Разделитель',
  'callout': 'Выноска',
  'code': 'Код',
  'list': 'Список',
  'quote': 'Цитата',
  'columns': 'Колонки',
  'accordion': 'Аккордеон',
  'table': 'Таблица',
  'tabs': 'Табы',
  'embed': 'Встраивание',
  'gallery': 'Галерея',
  'button': 'Кнопка',
  'product-card': 'Карточка товара',
};

const blockTypeIcons = <String, int>{
  'heading': 0xe25c, // Icons.title
  'paragraph': 0xe261, // Icons.text_fields
  'image': 0xe3f4, // Icons.image_outlined
  'divider': 0xe262, // Icons.horizontal_rule
  'callout': 0xef48, // Icons.info_outline
  'code': 0xe86f, // Icons.code
  'list': 0xe241, // Icons.format_list_bulleted
  'quote': 0xe244, // Icons.format_quote
  'columns': 0xe949, // Icons.view_column_outlined
  'accordion': 0xe5cf, // Icons.expand_more
  'table': 0xef51, // Icons.table_chart_outlined
  'tabs': 0xe8d8, // Icons.tab
  'embed': 0xef67, // Icons.smart_display_outlined
  'gallery': 0xe3b6, // Icons.collections_outlined
  'button': 0xef69, // Icons.smart_button_outlined
  'product-card': 0xf37b, // Icons.storefront_outlined
};
