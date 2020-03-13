(ns ethlance.ui.coeffect.storage
  "Coeffects for dealing with local storage"
  (:require [akiroz.re-frame.storage :refer [reg-co-fx!]]))


;; coeffect id `:store`
(reg-co-fx! :ethlance-app {:cofx :store})
