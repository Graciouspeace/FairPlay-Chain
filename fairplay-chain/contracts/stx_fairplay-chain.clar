;; ClarityBet: Decentralized Gambling Platform
;; A fair and transparent casino implemented in Clarity for the Stacks blockchain

;; Define constants
(define-constant contract-owner tx-sender)
(define-constant house-fee-percent u5) ;; 5% house fee
(define-constant min-bet u1000000) ;; Minimum bet in microSTX (1 STX)
(define-constant max-bet u1000000000) ;; Maximum bet in microSTX (1000 STX)

;; Define error codes
(define-constant err-owner-only (err u100))
(define-constant err-invalid-bet (err u101))
(define-constant err-game-not-found (err u102))
(define-constant err-insufficient-balance (err u103))
(define-constant err-unauthorized (err u104))
(define-constant err-invalid-game-state (err u105))
(define-constant err-game-completed (err u106))
(define-constant err-invalid-param (err u107))

;; Data structures

;; Game States
(define-data-var house-balance uint u0)
(define-data-var total-games-played uint u0)
(define-data-var total-stx-wagered uint u0)

;; Game types
(define-constant GAME-TYPE-COINFLIP u1)
(define-constant GAME-TYPE-DICEROLL u2)
(define-constant GAME-TYPE-ROULETTE u3)

;; Game status
(define-constant STATUS-ACTIVE u1)
(define-constant STATUS-COMPLETED u2)
(define-constant STATUS-REFUNDED u3)

;; Game structure
(define-map games
  { game-id: uint }
  {
    creator: principal,
    game-type: uint,
    bet-amount: uint,
    status: uint,
    created-at: uint,
    completed-at: uint,
    result: (optional uint),
    player-choice: uint,
    winning-choice: (optional uint),
    payout-amount: (optional uint)
  }
)

;; Game counters
(define-data-var next-game-id uint u1)

;; Helper functions

;; Get current block information for randomness
(define-read-only (get-random-seed)
  (get-block-info? vrf-seed u0)
)

;; Calculate house fee
(define-read-only (calculate-house-fee (bet-amount uint))
  (/ (* bet-amount house-fee-percent) u100)
)

;; Get current time (block height as a proxy for time)
(define-read-only (get-current-time)
  block-height
)

;; Generate pseudo-random number using block VRF seed and game ID
;; Returns a value between min (inclusive) and max (inclusive)
(define-read-only (generate-random-number (game-id uint) (min uint) (max uint))
  (let 
    (
      (range (+ (- max min) u1))
      (seed-opt (get-random-seed))
    )
    (if (is-some seed-opt)
      (let 
        (
          (seed (unwrap! seed-opt u0))
          (combined-seed (xor seed game-id))
          (hash (sha256 (unwrap! (to-consensus-buff? combined-seed) 0x)))
          (random-value (mod (+ (buff-to-uint-le hash) u1) range))
        )
        (+ min random-value)
      )
      ;; If no seed is available, fallback to less secure method
      (mod (+ (var-get next-game-id) u1) range)
    )
  )
)

;; Convert a hash value to uint (little-endian)
(define-read-only (buff-to-uint-le (byte-array (buff 32)))
  (let 
    (
      (byte-0 (buff-to-uint (unwrap-panic (element-at byte-array u0))))
      (byte-1 (buff-to-uint (unwrap-panic (element-at byte-array u1))))
      (byte-2 (buff-to-uint (unwrap-panic (element-at byte-array u2))))
      (byte-3 (buff-to-uint (unwrap-panic (element-at byte-array u3))))
    )
    (+ byte-0 (+ (<< byte-1 u8 >) (+ (<< byte-2 u16 >) (<< byte-3 u24 >))))
  )
)

;; Get a specific game
(define-read-only (get-game (game-id uint))
  (map-get? games { game-id: game-id })
)

;; Admin functions

;; Withdraw house fees (owner only)
(define-public (withdraw-house-fees (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= amount (var-get house-balance)) err-insufficient-balance)
    (var-set house-balance (- (var-get house-balance) amount))
    (as-contract (stx-transfer? amount contract-address tx-sender))
  )
)

;; Update house fee percentage (owner only)
(define-public (update-house-fee (new-fee-percent uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee-percent u20) err-invalid-param) ;; Max 20% fee
    (ok (var-set house-fee-percent new-fee-percent))
  )
)

;; Update bet limits (owner only)
(define-public (update-bet-limits (new-min-bet uint) (new-max-bet uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (< new-min-bet new-max-bet) err-invalid-param)
    (ok (begin
      (define-constant min-bet new-min-bet)
      (define-constant max-bet new-max-bet)
    ))
  )
)

;; Game implementations

;; Coin Flip (50/50)
;; Player choice: 0 for Heads, 1 for Tails
(define-public (play-coinflip (choice uint) (bet-amount uint))
  (begin
    (asserts! (or (is-eq choice u0) (is-eq choice u1)) err-invalid-param)
    (asserts! (and (>= bet-amount min-bet) (<= bet-amount max-bet)) err-invalid-bet)
    
    ;; Create the game
    (let
      (
        (game-id (var-get next-game-id))
        (house-fee (calculate-house-fee bet-amount))
        (potential-win-amount (* bet-amount u2))
      )
      
      ;; Increment game counter
      (var-set next-game-id (+ game-id u1))
      (var-set total-games-played (+ (var-get total-games-played) u1))
      (var-set total-stx-wagered (+ (var-get total-stx-wagered) bet-amount))
      
      ;; Transfer STX from player to contract
      (unwrap! (stx-transfer? bet-amount tx-sender contract-address) err-insufficient-balance)
      
      ;; Store game data
      (map-set games
        { game-id: game-id }
        {
          creator: tx-sender,
          game-type: GAME-TYPE-COINFLIP,
          bet-amount: bet-amount,
          status: STATUS-ACTIVE,
          created-at: (get-current-time),
          completed-at: u0,
          result: none,
          player-choice: choice,
          winning-choice: none,
          payout-amount: none
        }
      )
      
      ;; Resolve the game immediately (for this implementation)
      ;; In production, you might want to use a commit-reveal scheme or VRF
      (resolve-coinflip game-id)
    )
  )
)

;; Resolve coin flip game
(define-private (resolve-coinflip (game-id uint))
  (let
    (
      (game (unwrap! (map-get? games { game-id: game-id }) err-game-not-found))
      (bet-amount (get bet-amount game))
      (player-choice (get player-choice game))
      (player (get creator game))
    )
    
    (asserts! (is-eq (get status game) STATUS-ACTIVE) err-game-completed)
    
    (let
      (
        (result (generate-random-number game-id u0 u1))
        (house-fee (calculate-house-fee bet-amount))
        (win-amount (- (* bet-amount u2) house-fee))
        (win (is-eq result player-choice))
      )
      
      ;; Update game data
      (map-set games
        { game-id: game-id }
        (merge game {
          status: STATUS-COMPLETED,
          completed-at: (get-current-time),
          result: (some result),
          winning-choice: (some result),
          payout-amount: (if win (some win-amount) none)
        })
      )
      
      ;; Update house balance and pay winner if applicable
      (var-set house-balance (+ (var-get house-balance) house-fee))
      
      (if win
        (as-contract (stx-transfer? win-amount contract-address player))
        (ok true)
      )
    )
  )
)

;; Dice Roll
;; Player wins if they roll higher than their target (1-6)
;; The lower the target, the higher the potential payout
(define-public (play-diceroll (target-number uint) (bet-amount uint))
  (begin
    (asserts! (and (>= target-number u1) (<= target-number u5)) err-invalid-param)
    (asserts! (and (>= bet-amount min-bet) (<= bet-amount max-bet)) err-invalid-bet)
    
    ;; Create the game
    (let
      (
        (game-id (var-get next-game-id))
        (house-fee (calculate-house-fee bet-amount))
      )
      
      ;; Increment game counter
      (var-set next-game-id (+ game-id u1))
      (var-set total-games-played (+ (var-get total-games-played) u1))
      (var-set total-stx-wagered (+ (var-get total-stx-wagered) bet-amount))
      
      ;; Transfer STX from player to contract
      (unwrap! (stx-transfer? bet-amount tx-sender contract-address) err-insufficient-balance)
      
      ;; Store game data
      (map-set games
        { game-id: game-id }
        {
          creator: tx-sender,
          game-type: GAME-TYPE-DICEROLL,
          bet-amount: bet-amount,
          status: STATUS-ACTIVE,
          created-at: (get-current-time),
          completed-at: u0,
          result: none,
          player-choice: target-number,
          winning-choice: none,
          payout-amount: none
        }
      )
      
      ;; Resolve the game immediately
      (resolve-diceroll game-id)
    )
  )
)

;; Resolve dice roll game
(define-private (resolve-diceroll (game-id uint))
  (let
    (
      (game (unwrap! (map-get? games { game-id: game-id }) err-game-not-found))
      (bet-amount (get bet-amount game))
      (target-number (get player-choice game))
      (player (get creator game))
    )
    
    (asserts! (is-eq (get status game) STATUS-ACTIVE) err-game-completed)
    
    (let
      (
        (result (generate-random-number game-id u1 u6))
        (house-fee (calculate-house-fee bet-amount))
        (win (> result target-number))
        ;; Calculate payout multiplier based on target
        ;; Lower targets have lower probability but higher payouts
        ;; Multiplier = 6 / (6 - target) to maintain expected value below 1
        (multiplier (/ u6 (- u6 target-number)))
        (win-amount (if win (- (* bet-amount multiplier) house-fee) u0))
      )
      
      ;; Update game data
      (map-set games
        { game-id: game-id }
        (merge game {
          status: STATUS-COMPLETED,
          completed-at: (get-current-time),
          result: (some result),
          winning-choice: (some target-number),
          payout-amount: (if win (some win-amount) none)
        })
      )
      
      ;; Update house balance and pay winner if applicable
      (var-set house-balance (+ (var-get house-balance) house-fee))
      
      (if win
        (as-contract (stx-transfer? win-amount contract-address player))
        (ok true)
      )
    )
  )
)

;; Roulette - Simplified version
;; Play options:
;; 0: Single number (0-36) - pays 35:1
;; 1: Red/Black (0=red, 1=black) - pays 1:1
;; 2: Even/Odd (0=even, 1=odd) - pays 1:1
;; 3: High/Low (0=low 1-18, 1=high 19-36) - pays 1:1
(define-public (play-roulette (bet-type uint) (bet-choice uint) (bet-amount uint))
  (begin
    ;; Validate bet type and choice
    (asserts! (and (>= bet-type u0) (<= bet-type u3)) err-invalid-param)
    (asserts! 
      (cond
        ((is-eq bet-type u0) (and (>= bet-choice u0) (<= bet-choice u36))) ;; Single number
        ((is-eq bet-type u1) (or (is-eq bet-choice u0) (is-eq bet-choice u1))) ;; Red/Black
        ((is-eq bet-type u2) (or (is-eq bet-choice u0) (is-eq bet-choice u1))) ;; Even/Odd
        ((is-eq bet-type u3) (or (is-eq bet-choice u0) (is-eq bet-choice u1))) ;; High/Low
        (true false) ;; Invalid bet type
      )
      err-invalid-param
    )
    
    (asserts! (and (>= bet-amount min-bet) (<= bet-amount max-bet)) err-invalid-bet)
    
    ;; Create the game
    (let
      (
        (game-id (var-get next-game-id))
        (house-fee (calculate-house-fee bet-amount))
        ;; Encode bet-type and bet-choice as a single number
        (encoded-choice (+ (* bet-type u100) bet-choice))
      )
      
      ;; Increment game counter
      (var-set next-game-id (+ game-id u1))
      (var-set total-games-played (+ (var-get total-games-played) u1))
      (var-set total-stx-wagered (+ (var-get total-stx-wagered) bet-amount))
      
      ;; Transfer STX from player to contract
      (unwrap! (stx-transfer? bet-amount tx-sender contract-address) err-insufficient-balance)
      
      ;; Store game data
      (map-set games
        { game-id: game-id }
        {
          creator: tx-sender,
          game-type: GAME-TYPE-ROULETTE,
          bet-amount: bet-amount,
          status: STATUS-ACTIVE,
          created-at: (get-current-time),
          completed-at: u0,
          result: none,
          player-choice: encoded-choice,
          winning-choice: none,
          payout-amount: none
        }
      )
      
      ;; Resolve the game immediately
      (resolve-roulette game-id)
    )
  )
)

;; Define which numbers are red on a standard roulette wheel
(define-private (is-red (number uint))
  (or 
    (is-eq number u1) (is-eq number u3) (is-eq number u5) 
    (is-eq number u7) (is-eq number u9) (is-eq number u12) 
    (is-eq number u14) (is-eq number u16) (is-eq number u18) 
    (is-eq number u19) (is-eq number u21) (is-eq number u23) 
    (is-eq number u25) (is-eq number u27) (is-eq number u30)
    (is-eq number u32) (is-eq number u34) (is-eq number u36)
  )
)

;; Resolve roulette game
(define-private (resolve-roulette (game-id uint))
  (let
    (
      (game (unwrap! (map-get? games { game-id: game-id }) err-game-not-found))
      (bet-amount (get bet-amount game))
      (encoded-choice (get player-choice game))
      (player (get creator game))
      (bet-type (/ encoded-choice u100))
      (bet-choice (mod encoded-choice u100))
    )
    
    (asserts! (is-eq (get status game) STATUS-ACTIVE) err-game-completed)
    
    (let
      (
        (result (generate-random-number game-id u0 u36)) ;; 0-36 roulette wheel
        (house-fee (calculate-house-fee bet-amount))
        (win-multiplier 
          (cond
            ((is-eq bet-type u0) (if (is-eq result bet-choice) u36 u0)) ;; Single number - 35:1 plus original bet
            ((is-eq bet-type u1) ;; Red/Black - 1:1
              (if (is-eq bet-choice u0) ;; Red
                (if (is-red result) u2 u0)
                (if (and (not (is-red result)) (not (is-eq result u0))) u2 u0)
              )
            )
            ((is-eq bet-type u2) ;; Even/Odd - 1:1
              (if (is-eq bet-choice u0) ;; Even
                (if (and (is-eq (mod result u2) u0) (not (is-eq result u0))) u2 u0)
                (if (is-eq (mod result u2) u1) u2 u0)
              )
            )
            ((is-eq bet-type u3) ;; High/Low - 1:1
              (if (is-eq bet-choice u0) ;; Low (1-18)
                (if (and (>= result u1) (<= result u18)) u2 u0)
                (if (> result u18) u2 u0)
              )
            )
            (true u0) ;; Default case - no win
          )
        )
        (win (> win-multiplier u0))
        (win-amount (if win (- (* bet-amount win-multiplier) house-fee) u0))
      )
      
      ;; Update game data
      (map-set games
        { game-id: game-id }
        (merge game {
          status: STATUS-COMPLETED,
          completed-at: (get-current-time),
          result: (some result),
          winning-choice: (some (+ (* bet-type u100) result)),
          payout-amount: (if win (some win-amount) none)
        })
      )
      
      ;; Update house balance and pay winner if applicable
      (var-set house-balance (+ (var-get house-balance) house-fee))
      
      (if win
        (as-contract (stx-transfer? win-amount contract-address player))
        (ok true)
      )
    )
  )
)

;; Read-only functions for statistics and state

;; Get platform statistics
(define-read-only (get-platform-stats)
  {
    house-balance: (var-get house-balance),
    total-games-played: (var-get total-games-played),
    total-stx-wagered: (var-get total-stx-wagered),
    house-fee-percent: house-fee-percent
  }
)

;; Get games by a specific player
(define-read-only (get-player-games (player principal))
  (fold check-player-games (list) (list (var-get total-games-played)))
)

;; Helper function for get-player-games
(define-private (check-player-games (games-list (list 10 uint)) (game-id uint))
  (let ((game (map-get? games { game-id: game-id })))
    (if (and (is-some game) (is-eq (get creator (unwrap! game { creator: principal })) tx-sender))
      (append games-list game-id)
      games-list
    )
  )
)

;; Emergency functions

;; Pause the contract (only used in emergency situations)
(define-data-var contract-paused bool false)

;; Pause/unpause contract (owner only)
(define-public (set-contract-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (var-set contract-paused paused))
  )
)

;; Check if contract is paused
(define-read-only (is-contract-paused)
  (var-get contract-paused)
)

;; Refund a specific game (owner only, emergency)
(define-public (emergency-refund (game-id uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    (let
      (
        (game (unwrap! (map-get? games { game-id: game-id }) err-game-not-found))
        (player (get creator game))
        (bet-amount (get bet-amount game))
      )
      
      (asserts! (is-eq (get status game) STATUS-ACTIVE) err-game-completed)
      
      ;; Mark game as refunded
      (map-set games
        { game-id: game-id }
        (merge game {
          status: STATUS-REFUNDED,
          completed-at: (get-current-time)
        })
      )
      
      ;; Return funds to player
      (as-contract (stx-transfer? bet-amount contract-address player))
    )
  )
)