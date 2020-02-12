(ns ethlance.ui.component.carousel
  (:require
   [react-transition-group :refer [CSSTransition TransitionGroup]]
   [reagent.core :as r]
   
   ;; Ethlance Components
   [ethlance.ui.component.button :refer [c-button c-button-icon-label c-circle-icon-button]]
   [ethlance.ui.component.circle-button :refer [c-circle-icon-button]]
   [ethlance.ui.component.profile-image :refer [c-profile-image]]
   [ethlance.ui.component.rating :refer [c-rating]]))


(def animation-duration 500) ;; ms


(defn c-carousel
  "Carousel Component for displaying multiple 'slides' of content

  # Keyword Arguments

  opts - Optional Arguments

  children - Each individual slide to be displayed within the carousel.

  # Optional Arguments (opts)

  :default-index - The index within the `children` to display
  first [default: 0]

  # Examples

  ```clojure
  [c-carousel {}
   [[c-feedback-slide feedback-1]
    [c-feedback-slide feedback-2]]]
  ```
  "
  [{:keys [] :or {} :as opts} children]
  (let []
    (r/create-class
     {:display-name "ethlance-carousel"
      :reagent-render
      (fn [opts children]
        (let []
          [:div.ethlance-carousel
           [:div.slide-listing
            (doall
             (for [[index child] (map-indexed vector children)]
               ^{:key (str "slide-element-" index)}
               [:div.slide-element child]))]

           [:div.button-listing
            [:div.back-button
             [c-circle-icon-button
              {:name :ic-arrow-left
               :hide? false
               :on-click 
               (fn [])}]]

            [:div.forward-button
             [c-circle-icon-button
              {:name :ic-arrow-right
               :hide? false
               :on-click
               (fn [])}]]]]))})))


(defn c-feedback-slide
  [{:keys [id rating] :as feedback}]
  [:div.feedback-slide
   [:div.profile-image
    [c-profile-image {}]]
   [:div.rating
    [c-rating {:rating rating :color :white}]]
   [:div.message
    "\"Everything about this is wonderful!\""]
   [:div.name
    "Brian Curran"]])
   
