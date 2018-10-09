(ns ethlance.server.contract.ds-guard
  "Functions for manipulating the DSGuard contract."
  (:require
   [cljs-web3.eth :as web3-eth]
   [district.server.smart-contracts :as contracts]))


(defn call
  "Call the DSGuard contract with the given `method-name` and using the
  given `args`."
  [method-name & args]
  (apply contracts/contract-call :ds-guard method-name args))


(def ANY
  "The ANY address for authority whitelisting."
  "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")


(defn permit!
  "Permit a given `src` address the authority to call methods at `dst`
  address with function signature `sig`.

  Key Arguments:
  
  :src - The source address.
  
  :dst - The destination address.

  :sig - The calldata Function Identifier.

  Optional Arguments - `opt`

  `opt` key-vals are web3 contract-call override options.

  Notes:

  - Providing ds-guard/ANY to any of the fields will permit ANYone
  authorization in that particular scenario.

  Examples:

  - (permit {:src ANY :dst (contract :foo) :sig ANY})
    ;; Anyone can call the contract :foo, on any method.

  - (permit {:src my-address :dst ANY :sig ANY})
    ;; `my-address` can call any contract, on any method.

  "
  [{:keys [:src :dst :sig]} & [opts]]
  (call :permit src dst sig (merge opts {:gas 100000})))


(defn can-call?
  "Returns true if the given `src` `dst` combination is authorized to
  perform the given contract-call defined by `sig`, otherwise false."
  [{:keys [:src :dst :sig]}]
  (call :can-call src dst sig))
