// category-highlight: lists the venue's categories and highlights every POI
// of one of them. See docs/features/category-highlight.md.
(function (core) {
  // Category id currently highlighted by highlightCategory, so a later call
  // knows which POIs' surfaces to revert first, and clearCategoryHighlight
  // knows what to undo.
  var highlightedCategoryId = null;

  core.onReset(function () {
    highlightedCategoryId = null;
  });

  function poisOfCategory(categoryId) {
    return core.venue.pois.filter(function (p) {
      return p.categories.some(function (c) { return c.id === categoryId; });
    });
  }

  function colorCategory(categoryId, color) {
    var venue = core.venue;
    poisOfCategory(categoryId).forEach(function (poi) {
      poi.surfaces.forEach(function (surface) { venue.updateSurface(surface, { color: color }); });
    });
  }

  core.register({
    // Returns the venue's full category list (venue.categories: Category[],
    // Category = { readonly id: string }) so the native side can render a
    // picker. category.id is a raw internal identifier (a numeric string on
    // this demo's shared map, e.g. "1".."11"), not itself human-readable;
    // the human-readable name comes from venue.translator.translateCategory().
    // Both id (used for filtering/highlighting) and label (used for display
    // only) are returned so the native side never needs to highlight by a
    // translated string.
    getCategories: function () {
      var venue = core.venue;
      if (!venue) return [];
      var locale = venue.currentLocale;
      return venue.categories.map(function (c) {
        var translated = venue.translator.translateCategory(c, locale);
        return { id: c.id, label: (translated && translated.name) || c.id };
      });
    },
    // Highlights every POI belonging to categoryId by setting its
    // surface(s)' color, built from venue.pois.filter() (no dedicated
    // "highlight by category" SDK method exists) + venue.updateSurface().
    // Only one category is highlighted at a time: whatever was highlighted
    // before is reverted to 'initial' first. POIs with no surfaces
    // (point/marker-only) are filtered in but simply produce no visible
    // change, since poi.surfaces is [].
    highlightCategory: function (categoryId) {
      if (!core.venue) return;
      if (highlightedCategoryId) colorCategory(highlightedCategoryId, 'initial');
      highlightedCategoryId = categoryId;
      colorCategory(categoryId, '#FF6B00');
    },
    // Reverts whatever highlightCategory last applied. Passing 'initial'
    // (not undefined) is required to actually restore the bundle-defined
    // color.
    clearCategoryHighlight: function () {
      if (!core.venue || !highlightedCategoryId) return;
      colorCategory(highlightedCategoryId, 'initial');
      highlightedCategoryId = null;
    },
  });
})(window.MapCore);
