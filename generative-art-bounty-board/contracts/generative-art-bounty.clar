;; Generative Art Bounty Board
;; Protocol for AI generative art bounties with automated winner selection

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u600))
(define-constant err-not-found (err u601))
(define-constant err-bounty-closed (err u602))
(define-constant err-invalid-amount (err u603))
(define-constant err-unauthorized (err u604))
(define-constant err-already-selected (err u605))

;; Data Variables
(define-data-var bounty-count uint u0)
(define-data-var submission-count uint u0)
(define-data-var nonce uint u0)

;; Data Maps
(define-map bounties uint
  {
    creator: principal,
    theme: (string-ascii 100),
    description: (string-ascii 200),
    reward: uint,
    deadline: uint,
    winner-selected: bool,
    selection-method: (string-ascii 20),
    created-at: uint
  }
)

(define-map submissions uint
  {
    bounty-id: uint,
    artist: principal,
    artwork-hash: (buff 32),
    is-winner: bool,
    submitted-at: uint
  }
)

(define-map bounty-submissions {bounty-id: uint} (list 100 uint))

(define-map artist-wins principal uint)

(define-map submission-votes {submission-id: uint, voter: principal} uint)

(define-map submission-total-votes uint {vote-count: uint, total-rating: uint})

(define-map artist-reputation principal {total-submissions: uint, total-votes: uint, average-rating: uint})

(define-map bounty-categories uint (string-ascii 50))

(define-map user-feedback {submission-id: uint, reviewer: principal} (string-ascii 200))

(define-map bounty-sponsors {bounty-id: uint, sponsor: principal} uint)