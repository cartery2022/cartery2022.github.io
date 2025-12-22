hexo.extend.filter.register('theme_inject', function (injects) {
  console.log('[inject] popular-posts loaded');

  // 兼容不同 NexT / 主题注入点：尽量多打几个常见位置
  const targets = ['sidebar', 'sidebarInner', 'postSidebar', 'sidebar-left', 'sidebar-right'];

  targets.forEach((t) => {
    if (injects[t] && typeof injects[t].file === 'function') {
      console.log('[inject] ->', t);
      injects[t].file(
        'popular-posts',
        'source/_data/popular-posts.njk',
        {},
        { cache: false }
      );
    }
  });
});
