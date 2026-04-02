import { apiInitializer } from "discourse/lib/api";
import {
  bindCollectionsNavigatorEvents,
  ensureCollectionsNavigatorMount,
  ensureCollectionsNavigatorModal,
  initializeCollectionsNavigatorState,
  refreshCollectionsNavigatorUI,
} from "../lib/collections-navigator-state";

export default apiInitializer("1.24.0", (api) => {
  api.onPageChange(() => {
    setTimeout(() => {
      initializeCollectionsNavigatorState(api);
      ensureCollectionsNavigatorMount();
      ensureCollectionsNavigatorModal(api);
      bindCollectionsNavigatorEvents(api);
      refreshCollectionsNavigatorUI(api);
    }, 400);
  });
});
