(ns ethlance.ui.effect.storage
  "Effects for dealing with local storage"
  (:require [akiroz.re-frame.storage :refer [reg-co-fx!]]))

;; effect id `:store`
(reg-co-fx! :ethlance-app {:fx :store})
