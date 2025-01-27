;; DecideX - Decentralized Prediction Market
;; This contract allows users to create markets, place bets, and resolve outcomes.

;; Define data structures
(define-data-var market-id uint u0) ;; Auto-incrementing market ID
(define-map markets { id: uint } { creator: principal, description: (string-ascii 100), outcome: (optional bool), resolved: bool, expiry: uint })
(define-map bets { market-id: uint, user: principal } { amount: uint, outcome: bool })
(define-constant PLATFORM_FEE u100) ;; Fee in microSTX (e.g., 100 microSTX = 0.0001 STX)
(define-constant FEE_RECIPIENT 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE) ;; Replace with your platform's fee recipient address

;; Error codes
(define-constant ERR_NOT_CREATOR (err u100))
(define-constant ERR_MARKET_RESOLVED (err u101))
(define-constant ERR_MARKET_NOT_RESOLVED (err u102))
(define-constant ERR_INVALID_BET (err u103))
(define-constant ERR_INSUFFICIENT_BALANCE (err u104))
(define-constant ERR_MARKET_EXPIRED (err u105))
(define-constant ERR_REFUND_NOT_ALLOWED (err u106))

;; Create a new prediction market with an expiry time
(define-public (create-market (description (string-ascii 100)) (expiry uint))
    (let ((id (var-get market-id)))
        (map-set markets { id: id } { creator: tx-sender, description: description, outcome: none, resolved: false, expiry: expiry })
        (var-set market-id (+ id u1))
        (ok id)
    )
)

;; Place a bet on a market outcome (with platform fee)
(define-public (place-bet (market-identifier uint) (outcome bool) (amount uint))
    (let (
        (market (map-get? markets { id: market-identifier })))
        (asserts! (is-some market) ERR_INVALID_BET)
        (let (
            (market-data (unwrap-panic market))
            (resolved (get resolved market-data))
            (expiry (get expiry market-data)))
            (asserts! (not resolved) ERR_MARKET_RESOLVED)
            (asserts! (> expiry block-height) ERR_MARKET_EXPIRED) ;; Ensure market has not expired
            (asserts! (>= (stx-get-balance tx-sender) (+ amount PLATFORM_FEE)) ERR_INSUFFICIENT_BALANCE)
            (map-set bets { market-id: market-identifier, user: tx-sender } { amount: amount, outcome: outcome })
            (try! (stx-transfer? amount tx-sender (as-contract tx-sender))) ;; Transfer bet amount to contract
            (try! (stx-transfer? PLATFORM_FEE tx-sender FEE_RECIPIENT)) ;; Transfer fee to platform
            (ok true)
        )
    )
)

;; Resolve a market (only the creator can resolve)
(define-public (resolve-market (market-identifier uint) (outcome bool))
    (let (
        (market (map-get? markets { id: market-identifier })))
        (asserts! (is-some market) ERR_INVALID_BET)
        (let (
            (market-data (unwrap-panic market))
            (creator (get creator market-data))
            (resolved (get resolved market-data)))
            (asserts! (is-eq tx-sender creator) ERR_NOT_CREATOR)
            (asserts! (not resolved) ERR_MARKET_RESOLVED)
            (map-set markets 
                { id: market-identifier } 
                { 
                    creator: creator, 
                    description: (get description market-data), 
                    outcome: (some outcome), 
                    resolved: true, 
                    expiry: (get expiry market-data) 
                }
            )
            (ok true)
        )
    )
)

;; Claim winnings after a market is resolved
(define-public (claim-winnings (market-identifier uint))
    (let (
        (market (map-get? markets { id: market-identifier })))
        (asserts! (is-some market) ERR_INVALID_BET)
        (let (
            (market-data (unwrap-panic market))
            (resolved (get resolved market-data))
            (market-outcome (get outcome market-data))
            (bet (map-get? bets { market-id: market-identifier, user: tx-sender })))
            (asserts! resolved ERR_MARKET_NOT_RESOLVED)
            (asserts! (is-some market-outcome) ERR_MARKET_NOT_RESOLVED)
            (asserts! (is-some bet) ERR_INVALID_BET)
            (let (
                (bet-data (unwrap-panic bet))
                (amount (get amount bet-data))
                (bet-outcome (get outcome bet-data)))
                (asserts! (is-eq bet-outcome (unwrap-panic market-outcome)) ERR_INVALID_BET)
                (map-delete bets { market-id: market-identifier, user: tx-sender })
                (try! (stx-transfer? amount (as-contract tx-sender) tx-sender))
                (ok true)
            )
        )
    )
)

;; Refund a bet if the market is not resolved before expiry
(define-public (refund-bet (market-identifier uint))
    (let (
        (market (map-get? markets { id: market-identifier })))
        (asserts! (is-some market) ERR_INVALID_BET)
        (let (
            (market-data (unwrap-panic market))
            (resolved (get resolved market-data))
            (expiry (get expiry market-data))
            (bet (map-get? bets { market-id: market-identifier, user: tx-sender })))
            (asserts! (not resolved) ERR_MARKET_RESOLVED)
            (asserts! (<= expiry block-height) ERR_REFUND_NOT_ALLOWED) ;; Ensure market has expired
            (asserts! (is-some bet) ERR_INVALID_BET)
            (let (
                (bet-data (unwrap-panic bet))
                (amount (get amount bet-data)))
                (map-delete bets { market-id: market-identifier, user: tx-sender })
                (try! (stx-transfer? amount (as-contract tx-sender) tx-sender))
                (ok true)
            )
        )
    )
)