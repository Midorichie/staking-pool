(define-map stakers
  principal
  {
    amount: uint,
    start-block: uint
  }
)

(define-constant REWARD-RATE u10)

(define-public (stake (amount uint))
  (begin
    (asserts! (> amount u0) (err u100))
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set stakers tx-sender {
      amount: amount,
      start-block: block-height
    })
    (ok true)
  )
)

(define-public (claim)
  (match (map-get? stakers tx-sender) entry
    (let (
      (duration (- block-height (get start-block entry)))
      (amount (get amount entry))
      (reward (/ (* amount duration REWARD-RATE) u1000))
    )
      (begin
        (try! (stx-transfer? reward (as-contract tx-sender) tx-sender))
        (map-delete stakers tx-sender)
        (ok reward)
      )
    )
    (err u404)
  )
)

