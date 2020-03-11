(ns ethlance.ui.event.core
  "Contains initialization event handlers for ethlance"
  (:require
   [re-frame.core :as re]
   [district.ui.logging.events :as logging.events]))


(defn init
  "Initialization of ethlance re-frame resources"
  [{:as cofxs} [_]]
  (let []
    {:dispatch [::logging.events/info "Welcome!"]}))


;;
;; Registered Events
;;

(re/reg-event-fx :ethlance/init init)

