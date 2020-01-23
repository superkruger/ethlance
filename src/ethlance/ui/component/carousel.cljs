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
   [c-feedback-slide feedback-1]
   [c-feedback-slide feedback-2]]
  ```
  "
  [{:keys [default-index] :or {default-index 0} :as opts}
   children]
  (let [*slide-direction (r/atom :left)
        *current-index (r/atom default-index)]
    (r/create-class
     {:display-name "ethlance-carousel"
      :reagent-render
      (fn [opts & children]
        (let [first-slide? (<= @*current-index 0)
              last-slide? (>= @*current-index (dec (count children)))
              slide-direction-class (case @*slide-direction
                                      :left "animate-left"
                                      :right "animate-right")]
          [:div.ethlance-carousel
           [:> TransitionGroup
            {:component "div"
             :className "slide-listing"}
            (when-not first-slide?
              [:> CSSTransition
               {:key (str "left-slide-" (dec @*current-index))
                :in first-slide?
                :timeout animation-duration
                :classNames "left-slide"}
               [:div.left-slide
                {:class slide-direction-class}
                (nth children (dec @*current-index))]])

            [:> CSSTransition
             {:key (str "current-slide-" @*current-index)
              :in true
              :timeout animation-duration
              :classNames "current-slide"}
             [:div.current-slide
              {:class slide-direction-class}
              (nth children @*current-index)]]

            (when-not last-slide?
              [:> CSSTransition
               {:key (str "left-slide-" (inc @*current-index))
                :in last-slide?
                :timeout animation-duration
                :classNames "right-slide"}
               [:div.right-slide
                {:class slide-direction-class}
                (nth children (inc @*current-index))]])]

           [:div.button-listing
            [:div.back-button
             [c-circle-icon-button
              {:name :ic-arrow-left
               :hide? first-slide?
               :on-click 
               (fn []
                 (reset! *slide-direction :left)
                 (swap! *current-index dec))}]]
            [:div.forward-button
             [c-circle-icon-button
              {:name :ic-arrow-right
               :hide? last-slide?
               :on-click
               (fn []
                 (reset! *slide-direction :right)
                 (swap! *current-index inc))}]]]]))})))


(defn c-feedback-slide
  [{:keys [id rating] :as feedback}]
  [:div.feedback-slide
   ;; FIXME: use better unique key
   {:key (str "feedback-" id "-" rating)}
   [:div.profile-image
    [c-profile-image {}]]
   [:div.rating
    [c-rating {:rating rating :color :white}]]
   [:div.message
    "\"Everything about this is wonderful!\""]
   [:div.name
    "Brian Curran"]])
   
