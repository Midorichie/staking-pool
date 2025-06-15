;; Enhanced STX Staking Pool Contract
;; Fixes bugs and adds security enhancements

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-INVALID-AMOUNT (err u400))
(define-constant ERR-NO-STAKE-FOUND (err u404))
(define-constant ERR-INSUFFICIENT-BALANCE (err u402))
(define-constant ERR-TRANSFER-FAILED (err u403))
(define-constant ERR-ALREADY-STAKING (err u405))

;; Staking data structure
(define-map stakers
  principal
  {
    amount: uint,
    start-block: uint,
    last-claim-block: uint
  }
)

;; Contract state
(define-data-var total-staked uint u0)
(define-data-var reward-rate uint u10) ;; 1% per 1000 blocks
(define-data-var min-stake-amount uint u1000000) ;; 1 STX minimum
(define-data-var contract-active bool true)

;; Events
(define-data-var last-event-id uint u0)

;; Helper function to check if contract is active
(define-private (is-contract-active)
  (var-get contract-active)
)

;; Helper function to calculate rewards with better precision
(define-private (calculate-rewards (amount uint) (blocks uint))
  (let (
    (rate (var-get reward-rate))
    ;; Use higher precision calculation to avoid zero rewards
    (base-reward (/ (* amount blocks rate) u100000))
  )
    ;; Ensure minimum reward of 1 if any blocks have passed
    (if (and (> blocks u0) (is-eq base-reward u0))
      u1
      base-reward
    )
  )
)

;; Admin functions
(define-public (set-reward-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-rate u100) (err u406)) ;; Max 10% per 1000 blocks
    (var-set reward-rate new-rate)
    (ok true)
  )
)

(define-public (set-min-stake (new-min uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (and (> new-min u0) (<= new-min u100000000)) (err u406)) ;; Between 0 and 100 STX
    (var-set min-stake-amount new-min)
    (ok true)
  )
)

(define-public (toggle-contract (active bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set contract-active active)
    (ok true)
  )
)

;; Deposit STX to contract for reward payments (owner only)
(define-public (fund-contract (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (ok true)
  )
)

;; Enhanced staking function
(define-public (stake (amount uint))
  (let (
    (existing-stake (map-get? stakers tx-sender))
    (min-amount (var-get min-stake-amount))
  )
    (asserts! (is-contract-active) (err u407))
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= amount min-amount) (err u408))
    (asserts! (is-none existing-stake) ERR-ALREADY-STAKING)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update staker record
    (map-set stakers tx-sender {
      amount: amount,
      start-block: block-height,
      last-claim-block: block-height
    })
    
    ;; Update total staked
    (var-set total-staked (+ (var-get total-staked) amount))
    (ok true)
  )
)

;; Add to existing stake
(define-public (add-stake (additional-amount uint))
  (match (map-get? stakers tx-sender) existing-stake
    (let (
      (current-amount (get amount existing-stake))
      (start-block (get start-block existing-stake))
      (last-claim (get last-claim-block existing-stake))
      (new-total (+ current-amount additional-amount))
    )
      (asserts! (is-contract-active) (err u407))
      (asserts! (> additional-amount u0) ERR-INVALID-AMOUNT)
      
      ;; Transfer additional STX
      (try! (stx-transfer? additional-amount tx-sender (as-contract tx-sender)))
      
      ;; Update stake record
      (map-set stakers tx-sender {
        amount: new-total,
        start-block: start-block,
        last-claim-block: last-claim
      })
      
      ;; Update total staked
      (var-set total-staked (+ (var-get total-staked) additional-amount))
      (ok new-total)
    )
    ERR-NO-STAKE-FOUND
  )
)

;; Claim rewards without unstaking
(define-public (claim-rewards)
  (match (map-get? stakers tx-sender) entry
    (let (
      (amount (get amount entry))
      (start-block (get start-block entry))
      (last-claim-block (get last-claim-block entry))
      (blocks-since-claim (- block-height last-claim-block))
      (reward (calculate-rewards amount blocks-since-claim))
    )
      (asserts! (> blocks-since-claim u0) (err u409))
      (asserts! (> reward u0) (err u410))
      
      ;; Check contract has enough balance
      (asserts! (>= (stx-get-balance (as-contract tx-sender)) reward) ERR-INSUFFICIENT-BALANCE)
      
      ;; Transfer reward
      (try! (as-contract (stx-transfer? reward tx-sender tx-sender)))
      
      ;; Update last claim block
      (map-set stakers tx-sender {
        amount: amount,
        start-block: start-block,
        last-claim-block: block-height
      })
      
      (ok reward)
    )
    ERR-NO-STAKE-FOUND
  )
)

;; Unstake with rewards
(define-public (unstake)
  (match (map-get? stakers tx-sender) entry
    (let (
      (amount (get amount entry))
      (last-claim-block (get last-claim-block entry))
      (blocks-since-claim (- block-height last-claim-block))
      (reward (calculate-rewards amount blocks-since-claim))
      (total-return (+ amount reward))
    )
      ;; Check contract has enough balance for both stake and rewards
      (asserts! (>= (stx-get-balance (as-contract tx-sender)) total-return) ERR-INSUFFICIENT-BALANCE)
      
      ;; Transfer stake + rewards
      (try! (as-contract (stx-transfer? total-return tx-sender tx-sender)))
      
      ;; Remove from stakers map
      (map-delete stakers tx-sender)
      
      ;; Update total staked
      (var-set total-staked (- (var-get total-staked) amount))
      
      (ok {staked: amount, reward: reward, total: total-return})
    )
    ERR-NO-STAKE-FOUND
  )
)

;; Emergency unstake (principal only, no rewards)
(define-public (emergency-unstake)
  (match (map-get? stakers tx-sender) entry
    (let (
      (amount (get amount entry))
    )
      ;; Transfer only the principal stake
      (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
      
      ;; Remove from stakers map
      (map-delete stakers tx-sender)
      
      ;; Update total staked
      (var-set total-staked (- (var-get total-staked) amount))
      
      (ok amount)
    )
    ERR-NO-STAKE-FOUND
  )
)

;; Read-only functions
(define-read-only (get-staker-info (staker principal))
  (map-get? stakers staker)
)

(define-read-only (get-pending-rewards (staker principal))
  (match (map-get? stakers staker) entry
    (let (
      (amount (get amount entry))
      (last-claim-block (get last-claim-block entry))
      (blocks-since-claim (- block-height last-claim-block))
    )
      (ok (calculate-rewards amount blocks-since-claim))
    )
    ERR-NO-STAKE-FOUND
  )
)

(define-read-only (get-contract-stats)
  {
    total-staked: (var-get total-staked),
    reward-rate: (var-get reward-rate),
    min-stake: (var-get min-stake-amount),
    contract-balance: (stx-get-balance (as-contract tx-sender)),
    active: (var-get contract-active),
    current-block: block-height
  }
)
