;; DecideX - Decentralized Prediction Market
;; This contract allows users to create markets, place bets, and resolve outcomes.

;; Define data structures
(define-data-var market-id uint u0) ;; Auto-incrementing market ID
(define-map markets { id: uint } { creator: principal, description: (string-ascii 100), outcome: (optional bool), resolved: bool })
(define-map bets { market-id: uint, user: principal } { amount: uint, outcome: bool })

;; Error codes
(define-constant ERR_NOT_CREATOR (err u100))
(define-constant ERR_MARKET_RESOLVED (err u101))
(define-constant ERR_MARKET_NOT_RESOLVED (err u102))
(define-constant ERR_INVALID_BET (err u103))
(define-constant ERR_INSUFFICIENT_BALANCE (err u104))

;; Create a new prediction market
(define-public (create-market (description (string-ascii 100)))
    (let ((id (var-get market-id)))
        (map-set markets { id: id } { creator: tx-sender, description: description, outcome: none, resolved: false })
        (var-set market-id (+ id u1))
        (ok id)
    )
)

;; Place a bet on a market outcome
(define-public (place-bet (market-id uint) (outcome bool) (amount uint))
    (let (
        (market (map-get? markets { id: market-id }))
        (resolved (default-to false (get resolved market))))
        (asserts (is-ok market) ERR_INVALID_BET)
        (asserts (not resolved) ERR_MARKET_RESOLVED)
        (asserts (>= (stx-get-balance tx-sender) amount) ERR_INSUFFICIENT_BALANCE)
        (map-set bets { market-id: market-id, user: tx-sender } { amount: amount, outcome: outcome })
        (stx-transfer? amount tx-sender (contract-of decideX))
        (ok true)
    )
)

;; Resolve a market (only the creator can resolve)
(define-public (resolve-market (market-id uint) (outcome bool))
    (let (
        (market (map-get? markets { id: market-id }))
        (creator (default-to tx-sender (get creator market)))
        (resolved (default-to false (get resolved market))))
        (asserts (is-ok market) ERR_INVALID_BET)
        (asserts (is-eq tx-sender creator) ERR_NOT_CREATOR)
        (asserts (not resolved) ERR_MARKET_RESOLVED)
        (map-set markets { id: market-id } { creator: creator, description: (get description market), outcome: (some outcome), resolved: true })
        (ok true)
    )
)

;; Claim winnings after a market is resolved
(define-public (claim-winnings (market-id uint))
    (let (
        (market (map-get? markets { id: market-id }))
        (resolved (default-to false (get resolved market)))
        (outcome (default-to false (unwrap! (get outcome market) ERR_MARKET_NOT_RESOLVED)))
        (bet (map-get? bets { market-id: market-id, user: tx-sender }))
        (amount (default-to u0 (get amount bet)))
        (bet-outcome (default-to false (get outcome bet))))
        (asserts (is-ok market) ERR_INVALID_BET)
        (asserts resolved ERR_MARKET_NOT_RESOLVED)
        (asserts (is-ok bet) ERR_INVALID_BET)
        (asserts (is-eq bet-outcome outcome) ERR_INVALID_BET)
        (map-delete bets { market-id: market-id, user: tx-sender })
        (stx-transfer? amount (contract-of decideX) tx-sender)
        (ok true)
    )
)