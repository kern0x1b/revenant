# The supplementary views a collection view has on screen

The release lays supplementary views out and draws them, but never answers which of them are on
screen, so an application that scrolls a section header away and then reads it back has nothing to
read. The answer is built from the layout rather than from a list the view kept:

- `indexPathsForVisibleSupplementaryElementsOfKind:` is the elements of that kind the layout draws in
  the view's own bounds, each index path once, in the order the layout draws them.
- `visibleSupplementaryViewsOfKind:` is the view at each of those index paths.
- `supplementaryViewForElementKind:atIndexPath:` asks the layout first, because the layout decides
  whether there is a supplementary view of that kind at that path at all, and answers nil when there
  is none — which is what the host answers for an index path no layout draws one at. Among the views
  the view holds of that kind, the one it draws at that path is the one matched by frame.

A view that is not laid out is not on screen whatever the view might still be holding, which is why
the layout is asked before the view's own views are.
