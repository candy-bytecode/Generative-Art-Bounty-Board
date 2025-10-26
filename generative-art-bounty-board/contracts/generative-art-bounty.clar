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