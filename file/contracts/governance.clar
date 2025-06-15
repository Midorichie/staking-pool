;; Governance Contract for Staking Pool
;; Allows stakers to vote on parameter changes

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-INVALID-PROPOSAL (err u400))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-VOTED (err u405))
(define-constant ERR-PROPOSAL-EXPIRED (err u406))
(define-constant ERR-PROPOSAL-NOT-READY (err u407))
(define-constant ERR-NOT-STAKER (err u408))

;; Proposal types
(define-constant PROPOSAL-TYPE-REWARD-RATE u1)
(define-constant PROPOSAL-TYPE-MIN-STAKE u2)
(define-constant PROPOSAL-TYPE-EMERGENCY-PAUSE u3)

;; Proposal structure
(define-map proposals
  uint
  {
    proposer: principal,
    proposal-type: uint,
    new-value: uint,
    description: (string-ascii 256),
    start-block: uint,
    end-block: uint,
    votes-for: uint,
    votes-against: uint,
    executed: bool
  }
)

;; Vote tracking
(define-map votes
  {proposal-id: uint, voter: principal}
  {vote: bool, voting-power: uint}
)

;; Contract state
(define-data-var next-proposal-id uint u1)
(define-data-var voting-period uint u1440) ;; ~10 days in blocks
(define-data-var min-voting-power uint u1000000) ;; 1 STX minimum to vote

;; Get voting power (amount staked in staking contract)
(define-private (get-voting-power (voter principal))
  ;; In a real implementation, this would call:
  ;; (contract-call? .staking-pool get-staker-info voter)
  ;; For now, returning a placeholder
  u1000000
)

;; Create a new proposal
(define-public (create-proposal 
    (proposal-type uint) 
    (new-value uint) 
    (description (string-ascii 256)))
  (let (
    (proposal-id (var-get next-proposal-id))
    (voting-power (get-voting-power tx-sender))
  )
    ;; Validate proposal type
    (asserts! (or (is-eq proposal-type PROPOSAL-TYPE-REWARD-RATE)
                  (is-eq proposal-type PROPOSAL-TYPE-MIN-STAKE)
                  (is-eq proposal-type PROPOSAL-TYPE-EMERGENCY-PAUSE))
              ERR-INVALID-PROPOSAL)
    
    ;; Check voter has minimum voting power
    (asserts! (>= voting-power (var-get min-voting-power)) ERR-NOT-STAKER)
    
    ;; Validate description length (additional safety check)
    (asserts! (> (len description) u0) ERR-INVALID-PROPOSAL)
    
    ;; Validate proposal values
    (if (is-eq proposal-type PROPOSAL-TYPE-REWARD-RATE)
      (asserts! (<= new-value u100) ERR-INVALID-PROPOSAL) ;; Max 10%
      true
    )
    
    ;; Create proposal
    (map-set proposals proposal-id {
      proposer: tx-sender,
      proposal-type: proposal-type,
      new-value: new-value,
      description: description,
      start-block: block-height,
      end-block: (+ block-height (var-get voting-period)),
      votes-for: u0,
      votes-against: u0,
      executed: false
    })
    
    ;; Increment next proposal ID
    (var-set next-proposal-id (+ proposal-id u1))
    
    (ok proposal-id)
  )
)

;; Vote on a proposal
(define-public (vote (proposal-id uint) (support bool))
  (let (
    (voting-power (get-voting-power tx-sender))
    (vote-key {proposal-id: proposal-id, voter: tx-sender})
  )
    ;; Validate proposal-id is reasonable
    (asserts! (and (> proposal-id u0) (< proposal-id (var-get next-proposal-id))) ERR-PROPOSAL-NOT-FOUND)
    
    ;; Check proposal exists
    (match (map-get? proposals proposal-id) proposal
      (let (
        (end-block (get end-block proposal))
        (votes-for (get votes-for proposal))
        (votes-against (get votes-against proposal))
      )
        ;; Validations
        (asserts! (>= voting-power (var-get min-voting-power)) ERR-NOT-STAKER)
        (asserts! (<= block-height end-block) ERR-PROPOSAL-EXPIRED)
        (asserts! (is-none (map-get? votes vote-key)) ERR-ALREADY-VOTED)
        
        ;; Record vote
        (map-set votes vote-key {
          vote: support,
          voting-power: voting-power
        })
        
        ;; Update proposal vote counts
        (if support
          (map-set proposals proposal-id 
            (merge proposal {votes-for: (+ votes-for voting-power)}))
          (map-set proposals proposal-id 
            (merge proposal {votes-against: (+ votes-against voting-power)}))
        )
        
        (ok true)
      )
      ERR-PROPOSAL-NOT-FOUND
    )
  )
)

;; Execute a passed proposal (owner only for now)
(define-public (execute-proposal (proposal-id uint))
  (begin
    ;; Validate proposal-id is reasonable
    (asserts! (and (> proposal-id u0) (< proposal-id (var-get next-proposal-id))) ERR-PROPOSAL-NOT-FOUND)
    
    (match (map-get? proposals proposal-id) proposal
      (let (
        (end-block (get end-block proposal))
        (votes-for (get votes-for proposal))
        (votes-against (get votes-against proposal))
        (executed (get executed proposal))
        (proposal-type (get proposal-type proposal))
        (new-value (get new-value proposal))
      )
        ;; Validations
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (> block-height end-block) ERR-PROPOSAL-NOT-READY)
        (asserts! (not executed) (err u409))
        (asserts! (> votes-for votes-against) (err u410)) ;; Simple majority
        
        ;; Mark as executed
        (map-set proposals proposal-id 
          (merge proposal {executed: true}))
        
        ;; Execute based on proposal type
        ;; Note: In a real implementation, this would call the staking contract
        (if (is-eq proposal-type PROPOSAL-TYPE-REWARD-RATE)
          (begin
            ;; Would call (contract-call? .staking-pool set-reward-rate new-value)
            (ok "Reward rate updated"))
          (if (is-eq proposal-type PROPOSAL-TYPE-MIN-STAKE)
            (begin
              ;; Would call (contract-call? .staking-pool set-min-stake new-value)
              (ok "Minimum stake updated"))
            (if (is-eq proposal-type PROPOSAL-TYPE-EMERGENCY-PAUSE)
              (begin
                ;; Would call (contract-call? .staking-pool toggle-contract false)
                (ok "Emergency pause activated"))
              (err u411)
            )
          )
        )
      )
      ERR-PROPOSAL-NOT-FOUND
    )
  )
)

;; Read-only functions
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes {proposal-id: proposal-id, voter: voter})
)

(define-read-only (get-active-proposals)
  ;; This would return a list of active proposals
  ;; Simplified for this example
  {
    next-id: (var-get next-proposal-id),
    voting-period: (var-get voting-period)
  }
)

;; Admin functions
(define-public (set-voting-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= new-period u144) (<= new-period u14400)) (err u412)) ;; 1-100 days
    (var-set voting-period new-period)
    (ok true)
  )
)
