;; DecideX - Decentralized Prediction Market
;; This contract allows users to create markets, place bets, and resolve outcomes.

;; Define data structures
(define-data-var market-id uint u0) ;; Auto-incrementing market ID
(define-data-var contract-owner principal tx-sender)
(define-data-var shutdown-activated uint u0) ;; 0 = active, 1 = shutdown

(define-map markets { id: uint } { creator: principal, description: (string-ascii 100), outcome: (optional bool), resolved: bool, expiry: uint })
(define-map bets { market-id: uint, user: principal } { amount: uint, outcome: bool })
(define-map market-pools { market-id: uint, outcome: bool } { total: uint })

(define-constant PLATFORM_FEE u100) ;; Fee in microSTX (e.g., 100 microSTX = 0.0001 STX)
(define-constant FEE_RECIPIENT 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE)
(define-constant MIN_EXPIRY_BLOCKS u100) ;; Minimum number of blocks for market expiry
(define-constant MAX_EXPIRY_BLOCKS u52560) ;; Maximum number of blocks (approximately 1 year)
(define-constant MIN_BET_AMOUNT u1000) ;; Minimum bet amount in microSTX
(define-constant MAX_BET_AMOUNT u1000000000) ;; Maximum bet amount in microSTX

;; Error codes
(define-constant ERR_NOT_CREATOR (err u100))
(define-constant ERR_MARKET_RESOLVED (err u101))
(define-constant ERR_MARKET_NOT_RESOLVED (err u102))
(define-constant ERR_INVALID_BET (err u103))
(define-constant ERR_INSUFFICIENT_BALANCE (err u104))
(define-constant ERR_MARKET_EXPIRED (err u105))
(define-constant ERR_REFUND_NOT_ALLOWED (err u106))
(define-constant ERR_NOT_AUTHORIZED (err u107))
(define-constant ERR_SHUTDOWN_ACTIVE (err u108))
(define-constant ERR_INVALID_EXPIRY (err u109))
(define-constant ERR_INVALID_AMOUNT (err u110))
(define-constant ERR_INVALID_OWNER (err u111))
(define-constant ERR_INVALID_MARKET_ID (err u112))
(define-constant ERR_INVALID_DESCRIPTION (err u113))

;; Read-only helper to check shutdown status
(define-read-only (is-shutdown)
    (is-eq (var-get shutdown-activated) u1)
)

;; Helper to validate market ID
(define-private (is-valid-market-id (market-identifier uint))
    (<= market-identifier (var-get market-id))
)

;; Helper to validate description string
(define-private (is-valid-description (description (string-ascii 100)))
    (and 
        (>= (len description) u1)
        (<= (len description) u100)
    )
)

;; Owner-only function to toggle shutdown status
(define-public (toggle-shutdown)
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
        (ok (var-set shutdown-activated (if (is-shutdown) u0 u1)))
    )
)

;; Get detailed market information
(define-read-only (get-market-details (market-identifier uint))
    (begin
        (asserts! (is-valid-market-id market-identifier) ERR_INVALID_MARKET_ID)
        (let ((market (map-get? markets { id: market-identifier })))
            (if (is-some market)
                (let ((market-data (unwrap-panic market))
                      (true-pool (default-to u0 (get total (map-get? market-pools { market-id: market-identifier, outcome: true }))))
                      (false-pool (default-to u0 (get total (map-get? market-pools { market-id: market-identifier, outcome: false })))))
                    (ok {
                        creator: (get creator market-data),
                        description: (get description market-data),
                        outcome: (get outcome market-data),
                        resolved: (get resolved market-data),
                        expiry: (get expiry market-data),
                        true-pool: true-pool,
                        false-pool: false-pool,
                        total-liquidity: (+ true-pool false-pool)
                    })
                )
                ERR_INVALID_BET
            )
        )
    )
)

;; Calculate potential winnings
(define-read-only (calculate-potential-winnings (market-identifier uint) (bet-amount uint) (outcome bool))
    (begin
        (asserts! (is-valid-market-id market-identifier) ERR_INVALID_MARKET_ID)
        (asserts! (and (>= bet-amount MIN_BET_AMOUNT) (<= bet-amount MAX_BET_AMOUNT)) ERR_INVALID_AMOUNT)
        (let ((market (map-get? markets { id: market-identifier })))
            (if (is-some market)
                (let ((market-data (unwrap-panic market))
                      (chosen-pool (default-to u0 (get total (map-get? market-pools { market-id: market-identifier, outcome: outcome }))))
                      (opposite-pool (default-to u0 (get total (map-get? market-pools { market-id: market-identifier, outcome: (not outcome )}))))
                      (total-pool (+ chosen-pool opposite-pool)))
                    (if (> total-pool u0)
                        (ok (/ (* bet-amount total-pool) chosen-pool))
                        (ok bet-amount)
                    )
                )
                ERR_INVALID_BET
            )
        )
    )
)

;; Transfer contract ownership
(define-public (transfer-ownership (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
        (asserts! (not (is-eq new-owner tx-sender)) ERR_INVALID_OWNER)
        (asserts! (not (is-eq new-owner (var-get contract-owner))) ERR_INVALID_OWNER)
        (var-set contract-owner new-owner)
        (ok true)
    )
)

;; Create a new prediction market
(define-public (create-market (description (string-ascii 100)) (expiry uint))
    (begin
        (asserts! (not (is-shutdown)) ERR_SHUTDOWN_ACTIVE)
        (asserts! (is-valid-description description) ERR_INVALID_DESCRIPTION)
        (asserts! (and 
            (>= expiry (+ block-height MIN_EXPIRY_BLOCKS))
            (<= expiry (+ block-height MAX_EXPIRY_BLOCKS))) 
            ERR_INVALID_EXPIRY)
        (let ((id (var-get market-id)))
            (map-set markets 
                { id: id } 
                { 
                    creator: tx-sender, 
                    description: description, 
                    outcome: none, 
                    resolved: false, 
                    expiry: expiry 
                })
            (var-set market-id (+ id u1))
            (ok id)
        )
    )
)

;; Place a bet
(define-public (place-bet (market-identifier uint) (outcome bool) (amount uint))
    (begin
        (asserts! (not (is-shutdown)) ERR_SHUTDOWN_ACTIVE)
        (asserts! (is-valid-market-id market-identifier) ERR_INVALID_MARKET_ID)
        (asserts! (and (>= amount MIN_BET_AMOUNT) (<= amount MAX_BET_AMOUNT)) ERR_INVALID_AMOUNT)
        (let (
            (market (map-get? markets { id: market-identifier })))
            (asserts! (is-some market) ERR_INVALID_BET)
            (let (
                (market-data (unwrap-panic market))
                (resolved (get resolved market-data))
                (expiry (get expiry market-data))
                (current-pool (default-to { total: u0 } (map-get? market-pools { market-id: market-identifier, outcome: outcome }))))
                (asserts! (not resolved) ERR_MARKET_RESOLVED)
                (asserts! (> expiry block-height) ERR_MARKET_EXPIRED)
                (asserts! (>= (stx-get-balance tx-sender) (+ amount PLATFORM_FEE)) ERR_INSUFFICIENT_BALANCE)
                (map-set bets { market-id: market-identifier, user: tx-sender } { amount: amount, outcome: outcome })
                (map-set market-pools { market-id: market-identifier, outcome: outcome } { total: (+ (get total current-pool) amount) })
                (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
                (try! (stx-transfer? PLATFORM_FEE tx-sender FEE_RECIPIENT))
                (ok true)
            )
        )
    )
)

;; Resolve market
(define-public (resolve-market (market-identifier uint) (outcome bool))
    (begin
        (asserts! (is-valid-market-id market-identifier) ERR_INVALID_MARKET_ID)
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
)

;; Claim winnings
(define-public (claim-winnings (market-identifier uint))
    (begin
        (asserts! (is-valid-market-id market-identifier) ERR_INVALID_MARKET_ID)
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
)

;; Refund bet
(define-public (refund-bet (market-identifier uint))
    (begin
        (asserts! (is-valid-market-id market-identifier) ERR_INVALID_MARKET_ID)
        (let (
            (market (map-get? markets { id: market-identifier })))
            (asserts! (is-some market) ERR_INVALID_BET)
            (let (
                (market-data (unwrap-panic market))
                (resolved (get resolved market-data))
                (expiry (get expiry market-data))
                (bet (map-get? bets { market-id: market-identifier, user: tx-sender })))
                (asserts! (not resolved) ERR_MARKET_RESOLVED)
                (asserts! (<= expiry block-height) ERR_REFUND_NOT_ALLOWED)
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
)