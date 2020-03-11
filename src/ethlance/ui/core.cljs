(ns ethlance.ui.core
  "Web Application Entry Point"
  (:require
   [mount.core :as mount :refer [defstate]]
   [re-frame.core :as re]
   [taoensso.timbre :as log]

   ;; District UI Components
   [district.ui.reagent-render]
   [district.ui.router]
   [district.ui.component.router]
   [district.ui.logging]

   ;; Ethlance
   [ethlance.ui.config :as ui.config]
   [ethlance.ui.pages]
   [ethlance.ui.util.injection :as util.injection]
   [ethlance.ui.events]
   [ethlance.ui.effects]
   [ethlance.ui.coeffects]
   [ethlance.ui.subscriptions]))

(enable-console-print!)

(defn ^:export init
  "Main Entry Point function for ethlance ui"
  []
  (let [main-config (ui.config/get-config)]
    (.log js/console "Initializing...")
    (.log js/console (clj->js main-config))

    ;; Setup data-scroll attribute on #app dom element
    (util.injection/inject-data-scroll! {:injection-selector "#app"})

    ;; Mount our components
    (-> (mount/with-args main-config)
        (mount/start))

    ;; Do re-frame initialization
    (re/dispatch-sync [:ethlance/init])))


(defonce started? (init))
