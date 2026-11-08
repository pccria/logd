part of 'decorator.dart';

/// Manages the composition and application of [LogDecorator]s.
///
/// This class encapsulates the logic for sorting decorators based on their
/// structural priority (Content -> Box -> Hierarchy -> Visual) and applying
/// them to a [LogDocument].
@internal
class DecoratorPipeline {
  /// Creates a [DecoratorPipeline].
  const DecoratorPipeline(this.decorators) : _sorted = null;

  const DecoratorPipeline._cached(this.decorators, this._sorted);

  /// The list of decorators to apply.
  final List<LogDecorator> decorators;

  final List<LogDecorator>? _sorted;

  static final Expando<DecoratorPipeline> _instances = Expando();
  static final Expando<List<LogDecorator>> _sortedCache = Expando();

  /// Obtains a cached [DecoratorPipeline] for the given [decorators] list.
  static DecoratorPipeline of(final List<LogDecorator> decorators) {
    if (decorators.isEmpty) {
      return const DecoratorPipeline([]);
    }
    final cached = _instances[decorators];
    if (cached != null) {
      return cached;
    }
    final sorted = _sort(decorators);
    final pipeline = DecoratorPipeline._cached(decorators, sorted);
    _instances[decorators] = pipeline;
    _sortedCache[decorators] = sorted;
    return pipeline;
  }

  static List<LogDecorator> _sort(final List<LogDecorator> decorators) {
    if (decorators.isEmpty) {
      return const [];
    }
    final uniqueDecorators = decorators.toSet().toList();
    final indexedDecorators = uniqueDecorators.asMap().entries.toList()
      ..sort((final a, final b) {
        final priorityComparison =
            _priority(a.value).compareTo(_priority(b.value));
        if (priorityComparison != 0) {
          return priorityComparison;
        }
        // Stability: preserve original order for same-priority items.
        return a.key.compareTo(b.key);
      });

    return List.unmodifiable(
      indexedDecorators.map((final e) => e.value),
    );
  }

  /// The pre-sorted, deduplicated decorators ordered by structural priority.
  List<LogDecorator> get sortedDecorators {
    if (_sorted != null) {
      return _sorted;
    }
    final cached = _sortedCache[decorators];
    if (cached != null) {
      return cached;
    }
    final sorted = _sort(decorators);
    _sortedCache[decorators] = sorted;
    return sorted;
  }

  /// Applies the decorators to the [document].
  ///
  /// Decorators are first sorted by priority to ensure correct nesting:
  /// 1. [ContentDecorator] (innermost, modifies text)
  /// 2. [BoxDecorator] (wraps content)
  /// 3. [HierarchyDepthPrefixDecorator] (indents the box)
  /// 4. [VisualDecorator] (applies styles)
  /// 5. Others (outermost)
  void apply(
    final LogDocument document,
    final LogEntry entry,
    final LogPipelineFactory factory,
  ) {
    if (decorators.isEmpty) {
      return;
    }

    final activeDecorators = sortedDecorators;
    for (var i = 0; i < activeDecorators.length; i++) {
      activeDecorators[i].decorate(document, entry, factory);
    }
  }

  /// Calculates the total padding width required by all decorators.
  ///
  /// This is used to determine the effective available width for the content.
  int calculateTotalPadding(final LogEntry entry) {
    var total = 0;
    final active = sortedDecorators;
    for (var i = 0; i < active.length; i++) {
      total += active[i].paddingWidth(entry);
    }
    return total;
  }

  /// Calculates the padding reserved for structural decorators.
  ///
  /// Structural decorators (like boxes) reduce the "content limit", unlike
  /// visual decorators which might just add ANSI codes without taking up space.
  int calculateStructuralPadding(final LogEntry entry) {
    var total = 0;
    final active = sortedDecorators;
    for (var i = 0; i < active.length; i++) {
      final decorator = active[i];
      if (decorator is StructuralDecorator) {
        total += decorator.paddingWidth(entry);
      }
    }
    return total;
  }

  static int _priority(final LogDecorator decorator) {
    if (decorator is ContentDecorator) {
      return 0;
    }
    if (decorator is StructuralDecorator) {
      // Within Structural, Box comes before Hierarchy (Indentation).
      // Box wraps content, Hierarchy indents the wrapped box.
      if (decorator is BoxDecorator) {
        return 1;
      }
      if (decorator is HierarchyDepthPrefixDecorator) {
        return 2;
      }
      return 3; // Unknown structural decorators
    }
    if (decorator is VisualDecorator) {
      return 4;
    }
    return 5; // Unknown other decorators
  }
}
