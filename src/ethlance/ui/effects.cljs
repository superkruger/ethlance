(ns ethlance.ui.effects
  "Contains re-frame effects. Main entry for initializing/registering effects."
  (:require
   [cljs-web3.core :as web3.core]
   [re-frame.core :as re]

   ;; Ethlance Effects
   [ethlance.ui.effect.storage])) ;; :store


;; TODO: move this to maybe re-frame-web3-fx
(re/reg-fx
 :web3/personal-sign
 (fn [{:keys [web3 data-str from on-success on-error]}]
   (let [data (web3.core/to-hex data-str)]
     (.sendAsync (web3.core/current-provider web3)
                 (clj->js {:method "personal_sign"
                           :params [data-str from]
                           :from from})
                 (fn [err result]
                   (if err
                     (re/dispatch (conj on-error err))
                     (re/dispatch (conj on-success (aget result "result")))))))))
