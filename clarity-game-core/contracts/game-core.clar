
;; title: game-core
;; version:
;; summary:
;; description:

;; Action Game Smart Contract v2.0
;; Enhanced with robust error handling and input validation

;; Constants for game configuration
(define-constant MAX-GUILD-NAME-LENGTH u24)
(define-constant MAX-CHARACTER-NAME-LENGTH u24)
(define-constant MIN-GUILD-LEVEL-REQUIREMENT u10)
(define-constant MAX-GUILD-MEMBERS u100)
(define-constant MIN-CONTRIBUTION-AMOUNT u1)
(define-constant GUILD-CREATION-COST u1000)
(define-constant EXPERIENCE-PER-LEVEL u1000)
(define-constant COOLDOWN-BLOCKS u10)

;; Error Constants
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-INPUT (err u101))
(define-constant ERR-CHARACTER-EXISTS (err u102))
(define-constant ERR-CHARACTER-NOT-FOUND (err u103))
(define-constant ERR-EQUIPMENT-NOT-FOUND (err u104))
(define-constant ERR-INSUFFICIENT-LEVEL (err u105))
(define-constant ERR-COOLDOWN-ACTIVE (err u106))
(define-constant ERR-INSUFFICIENT-FUNDS (err u107))
(define-constant ERR-GUILD-EXISTS (err u108))
(define-constant ERR-GUILD-NOT-FOUND (err u109))
(define-constant ERR-NOT-GUILD-MASTER (err u110))
(define-constant ERR-ALREADY-IN-GUILD (err u111))
(define-constant ERR-GUILD-FULL (err u112))
(define-constant ERR-INVALID-NAME (err u113))
(define-constant ERR-INVALID-AMOUNT (err u114))
(define-constant ERR-INACTIVE-CHARACTER (err u115))
(define-constant ERR-INACTIVE-GUILD (err u116))

;; Principal Variables with Access Control
(define-data-var contract-administrator principal tx-sender)
(define-map administrators principal bool)

;; Character Profile Structure
(define-map character-profiles principal 
  {
    character-name: (string-ascii 24),
    character-class: (string-ascii 16),
    character-level: uint,
    combat-power: uint,
    health-points: uint,
    mana-points: uint,
    stamina-points: uint,
    experience-points: uint,
    skill-points: uint,
    achievement-score: uint,
    last-combat-timestamp: uint,
    creation-timestamp: uint,
    last-active-timestamp: uint,
    is-character-active: bool
  }
)

;; Equipment System with Enhanced Validation
(define-map equipment-inventory uint 
  {
    equipment-name: (string-ascii 24),
    equipment-type: (string-ascii 16),
    equipment-rarity: (string-ascii 12),
    attack-power: uint,
    defense-power: uint,
    magic-power: uint,
    durability: uint,
    max-durability: uint,
    level-requirement: uint,
    class-requirement: (optional (string-ascii 16)),
    equipment-owner: (optional principal),
    is-equipment-tradeable: bool,
    is-equipment-bound: bool,
    creation-timestamp: uint,
    last-modified-timestamp: uint
  }
)

;; Guild System with Enhanced Features
(define-map guild-data (string-ascii 24)
  {
    guild-master: principal,
    guild-officers: (list 5 principal),
    guild-level: uint,
    guild-experience: uint,
    member-count: uint,
    max-members: uint,
    guild-funds: uint,
    minimum-level-requirement: uint,
    guild-creation-time: uint,
    last-active-time: uint,
    guild-banner: (string-ascii 24),
    is-guild-active: bool,
    guild-achievement-score: uint,
    guild-description: (string-ascii 256)
  }
)

;; Private Functions for Input Validation
(define-private (validate-name (name (string-ascii 24)))
  (and
    (> (len name) u0)
    (<= (len name) MAX-CHARACTER-NAME-LENGTH)
    (is-eq (index-of name " ") none)  ;; No spaces allowed
  )
)

(define-private (validate-amount (amount uint))
  (and
    (>= amount MIN-CONTRIBUTION-AMOUNT)
    (<= amount u1000000000)  ;; Reasonable upper limit
  )
)

(define-private (validate-guild-name (name (string-ascii 24)))
  (and
    (validate-name name)
    (is-none (map-get? guild-data name))
  )
)

(define-private (is-administrator (user principal))
  (or
    (is-eq user (var-get contract-administrator))
    (default-to false (map-get? administrators user))
  )
)

(define-private (check-character-active (character principal))
  (match (map-get? character-profiles character)
    character-data (get is-character-active character-data)
    false
  )
)

;; Enhanced Character Creation with Validation
(define-public (create-character 
    (character-name (string-ascii 24))
    (character-class (string-ascii 16)))
  (let (
    (existing-character (map-get? character-profiles tx-sender))
  )
    (asserts! (validate-name character-name) ERR-INVALID-NAME)
    (asserts! (is-none existing-character) ERR-CHARACTER-EXISTS)
    
    (ok (map-set character-profiles tx-sender {
      character-name: character-name,
      character-class: character-class,
      character-level: u1,
      combat-power: u100,
      health-points: u1000,
      mana-points: u500,
      stamina-points: u1000,
      experience-points: u0,
      skill-points: u0,
      achievement-score: u0,
      last-combat-timestamp: u0,
      creation-timestamp: block-height,
      last-active-timestamp: block-height,
      is-character-active: true
    }))
  )
)

;; Enhanced Guild Creation with Validation
(define-public (create-guild
    (guild-name (string-ascii 24))
    (guild-banner (string-ascii 24))
    (guild-description (string-ascii 256)))
  (let (
    (character-data (unwrap! (map-get? character-profiles tx-sender) ERR-CHARACTER-NOT-FOUND))
  )
    ;; Input validation
    (asserts! (validate-guild-name guild-name) ERR-INVALID-NAME)
    (asserts! (validate-name guild-banner) ERR-INVALID-NAME)
    (asserts! (>= (get character-level character-data) MIN-GUILD-LEVEL-REQUIREMENT) ERR-INSUFFICIENT-LEVEL)
    (asserts! (check-character-active tx-sender) ERR-INACTIVE-CHARACTER)
    
    ;; Create guild with enhanced data
    (ok (map-set guild-data guild-name {
      guild-master: tx-sender,
      guild-officers: (list tx-sender),
      guild-level: u1,
      guild-experience: u0,
      member-count: u1,
      max-members: MAX-GUILD-MEMBERS,
      guild-funds: u0,
      minimum-level-requirement: u5,
      guild-creation-time: block-height,
      last-active-time: block-height,
      guild-banner: guild-banner,
      is-guild-active: true,
      guild-achievement-score: u0,
      guild-description: guild-description
    }))
  )
)

;; Enhanced Combat System
(define-public (initiate-combat (opponent principal))
  (let (
    (attacker-data (unwrap! (map-get? character-profiles tx-sender) ERR-CHARACTER-NOT-FOUND))
    (defender-data (unwrap! (map-get? character-profiles opponent) ERR-CHARACTER-NOT-FOUND))
    (current-block (unwrap! block-height u0))
  )
    ;; Comprehensive validation
    (asserts! (check-character-active tx-sender) ERR-INACTIVE-CHARACTER)
    (asserts! (check-character-active opponent) ERR-INACTIVE-CHARACTER)
    (asserts! (> (- current-block (get last-combat-timestamp attacker-data)) COOLDOWN-BLOCKS) ERR-COOLDOWN-ACTIVE)
    (asserts! (>= (get health-points attacker-data) u100) ERR-INSUFFICIENT-STATS)
    
    ;; Update combat timestamp
    (ok (map-set character-profiles tx-sender 
      (merge attacker-data {
        last-combat-timestamp: current-block,
        last-active-timestamp: current-block
      })
    ))
  )
)

;; Safe Guild Contribution System
(define-public (contribute-to-guild (amount uint))
  (let (
    (member-data (unwrap! (map-get? guild-members tx-sender) ERR-GUILD-NOT-FOUND))
    (guild-name (get guild-name member-data))
    (guild (unwrap! (map-get? guild-data guild-name) ERR-GUILD-NOT-FOUND))
  )
    ;; Input validation
    (asserts! (validate-amount amount) ERR-INVALID-AMOUNT)
    (asserts! (get is-guild-active guild) ERR-INACTIVE-GUILD)
    (asserts! (check-character-active tx-sender) ERR-INACTIVE-CHARACTER)
    
    ;; Update contribution safely
    (try! (map-set guild-members tx-sender 
      (merge member-data {
        contribution-points: (+ (get contribution-points member-data) amount),
        last-contribution-time: block-height
      })
    ))
    
    ;; Update guild data safely
    (ok (map-set guild-data guild-name 
      (merge guild {
        guild-funds: (+ (get guild-funds guild) amount),
        guild-experience: (+ (get guild-experience guild) (* amount u10)),
        last-active-time: block-height
      })
    ))
  )
)

;; Administrative Functions with Access Control
(define-public (set-administrator (admin principal) (status bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-administrator)) ERR-UNAUTHORIZED)
    (ok (map-set administrators admin status))
  )
)

;; Enhanced Read-only Functions
(define-read-only (get-character-details (player principal))
  (match (map-get? character-profiles player)
    character-data (if (get is-character-active character-data)
                    (some character-data)
                    none)
    none
  )
)

(define-read-only (get-guild-details (guild-name (string-ascii 24)))
  (match (map-get? guild-data guild-name)
    guild-data (if (get is-guild-active guild-data)
                    (some guild-data)
                    none)
    none
  )
)