(ns ethlance.server.graphql.resolvers.arbiter
  "GraphQL Resolvers defined for a Arbiter, or Arbiter Listings."
  (:require
   [bignumber.core :as bn]
   [cljs-time.core :as t]
   [cljs-web3.core :as web3-core]
   [cljs-web3.eth :as web3-eth]
   [cljs-web3.async.eth :as web3-eth-async]
   [cljs.core.match :refer-macros [match]]
   [cljs.nodejs :as nodejs]
   [cuerdas.core :as str]
   [taoensso.timbre :as log]

   [district.shared.error-handling :refer [try-catch]]
   [district.graphql-utils :as graphql-utils]
   [district.server.config :refer [config]]
   [district.server.db :as district.db]
   [district.server.smart-contracts :as contracts]
   [district.server.web3 :as web3]
   [district.server.db :as district.db]

   [ethlance.server.db :as ethlance.db]
   [ethlance.server.model.user :as model.user]
   [ethlance.server.model.arbiter :as model.arbiter]))


(defn arbiter-query
  "Main Resolver for Arbiter Data"
  [_ {:keys [:user/id]}]
  (log/debug (str "Querying for Arbiter: " id))
  (try-catch
   (when (> id 0)
     (model.arbiter/get-data id))))


(defn arbiter-search-query
  ""
  [_ {:keys []}])
