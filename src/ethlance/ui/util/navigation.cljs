(ns ethlance.ui.util.navigation
  "Functions for dealing with routes and URLs"
  (:require
   [district.ui.router.events :as router.events]
   [re-frame.core :as re]))


(defn create-handler
  "Generate a re-frame dispatch function for buttons to navigate to other pages.

  # Keyword Parameters

  :route - key of the given route

  :params - Keyword Parameters defined in bide route.

  :query - Query Parameters ex. {:foo 123 :bar \"abc\"} --> <url>?foo=123&bar=abc

  # Notes

  - Routes can be found at `ethlance.shared.routes`

  - This is used primarily for creating handlers for the :on-click
  event in reagent components."
  [{:keys [route params query]}]
  (fn [event]
    (.preventDefault event)
    (re/dispatch [::router.events/navigate route params query])
    false))


(defn resolve-route
  "Resolve a given route with the given params and query

   # Notes

   - Used to populate buttons with an :href"
  [{:keys [route params query]}]
  @(re/subscribe [:district.ui.router.subs/resolve route params query]))
