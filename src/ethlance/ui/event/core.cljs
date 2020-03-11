(ns ethlance.ui.event.core
  "Contains initialization event handlers for ethlance"
  (:require
   [re-frame.core :as re]))


(defn init
  "Initialization of ethlance re-frame resources"
  [{:as cofxs} [_]])


;;
;; Registered Events
;;

(re/reg-event-fx :ethlance/init init)

