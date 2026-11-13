import 'dart:math';

/// 启动页励志语句。
///
/// 当前为占位清单：收到正式文案后直接替换 [all] 的内容即可，其余代码无需改动。
class MotivationalQuotes {
  MotivationalQuotes._();

  static const List<String> all = [
    '日拱一卒，功不唐捐',
    '慢慢来，比较快',
    '不必急着抵达，先稳稳划好这一桨',
    '你写下的每一页，都在为上岸铺路',
    '把今天过踏实，岸就在前面',
  ];

  /// 随机取一句（允许与上次重复）；[random] 供测试注入固定种子。
  static String pick([Random? random]) {
    final generator = random ?? Random();
    return all[generator.nextInt(all.length)];
  }
}
