(ns ethlance.ui.util.interceptor
  "Interceptors for re-frame event handlers
  
   https://github.com/day8/re-frame/blob/master/docs/Interceptors.md"
  (:require
   [clojure.spec.alpha :as s]
   [re-frame.core :as re]))


(def trim-event
  "Remove the first argument in the re-frame coeffect event vector.

   Notes:

   - First argument in an event vector is the event name, followed by
   the event arguments.

   - Functionally equivalent to `trim-event` example in re-frame docs
  "
  re/trim-v)


(def unbox-event
  "Unbox the coeffect event vector if it is a single value.

   Notes:

   - Throws an error if there is more or less than one value in the event vector

   - Needs to be chained with `trim-arg` to be effective"
  (re/->interceptor
   :id :unbox-event
   :before
   (fn [context]
     (let [event-arg-count (-> context :coeffects :event count)
           unbox-fn (fn [event] (-> event first))]
       (if (= event-arg-count 1)
         (update-in context [:coeffects :event] unbox-fn)
         (throw (ex-info "Expected One Argument in Coeffect Event Vector"
                         {:expected-arg-count 1
                          :event-arg-count event-arg-count
                          :event-arguments (-> context :coeffects :event)})))))))


(defn spec-conform
  "Conform the coeffect event argument at `index`, with the given `spec`

   Keyword Arguments:
  
   spec - The spec to check against the event argument.

   Optional Arguments:

   index - The index of the argument to perform the spec conform on [default: 0]
  "
  [spec & [index]]
  (let []
    (re/->interceptor
     :id :spec-conform
     :before
     (fn [context]
       (let [index (or index 0)
             event-vector (-> context :coeffects :event)
             event-arg-count (count event-vector)]
         (cond
           ;; Make sure the index lies within the event vector bounds
           (<= event-arg-count index)
           (throw (ex-info "Argument Index out of bounds"
                           {:event-arg-count event-arg-count
                            :index index}))
           
           ;; Check to make sure the event argument is valid with the provided `spec`
           (not (s/valid? spec (nth event-vector index)))
           (throw (ex-info "Event Argument Fails Spec Conform"
                           {:spec spec
                            :index index
                            :event-vector event-vector
                            :event-argument (nth event-vector index)}))

           :else context))))))

