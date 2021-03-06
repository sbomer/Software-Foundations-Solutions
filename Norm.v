(** * Norm: Normalization of STLC *)

(* Chapter maintained by Andrew Tolmach *)

(* (Based on TAPL Ch. 12.) *)

Require Export Smallstep.
Hint Constructors multi.

(**
(This chapter is optional.)

In this chapter, we consider another fundamental theoretical property
of the simply typed lambda-calculus: the fact that the evaluation of a
well-typed program is guaranteed to halt in a finite number of
steps---i.e., every well-typed term is _normalizable_.

Unlike the type-safety properties we have considered so far, the
normalization property does not extend to full-blown programming
languages, because these languages nearly always extend the simply
typed lambda-calculus with constructs, such as general recursion
(as we discussed in the MoreStlc chapter) or recursive types, that can
be used to write nonterminating programs.  However, the issue of
normalization reappears at the level of _types_ when we consider the
metatheory of polymorphic versions of the lambda calculus such as
F_omega: in this system, the language of types effectively contains a
copy of the simply typed lambda-calculus, and the termination of the
typechecking algorithm will hinge on the fact that a ``normalization''
operation on type expressions is guaranteed to terminate.

Another reason for studying normalization proofs is that they are some
of the most beautiful---and mind-blowing---mathematics to be found in
the type theory literature, often (as here) involving the fundamental
proof technique of _logical relations_.

The calculus we shall consider here is the simply typed
lambda-calculus over a single base type [bool] and with pairs. We'll
give full details of the development for the basic lambda-calculus
terms treating [bool] as an uninterpreted base type, and leave the
extension to the boolean operators and pairs to the reader.  Even for
the base calculus, normalization is not entirely trivial to prove,
since each reduction of a term can duplicate redexes in subterms. *)

(** **** Exercise: 1 star  *)
(** Where do we fail if we attempt to prove normalization by a
straightforward induction on the size of a well-typed term? *)

(* tapp *)
(** [] *)

(* ###################################################################### *)
(** * Language *)

(** We begin by repeating the relevant language definition, which is
similar to those in the MoreStlc chapter, and supporting results
including type preservation and step determinism.  (We won't need
progress.)  You may just wish to skip down to the Normalization
section... *)

(* ###################################################################### *)
(** *** Syntax and Operational Semantics *)

Inductive ty : Type :=
  | TBool : ty
  | TArrow : ty -> ty -> ty
  | TProd  : ty -> ty -> ty
.

Tactic Notation "T_cases" tactic(first) ident(c) :=
  first;
  [ Case_aux c "TBool" | Case_aux c "TArrow" | Case_aux c "TProd" ].

Inductive tm : Type :=
    (* pure STLC *)
  | tvar : id -> tm
  | tapp : tm -> tm -> tm
  | tabs : id -> ty -> tm -> tm
    (* pairs *)
  | tpair : tm -> tm -> tm
  | tfst : tm -> tm
  | tsnd : tm -> tm
    (* booleans *)
  | ttrue : tm
  | tfalse : tm
  | tif : tm -> tm -> tm -> tm.
          (* i.e., [if t0 then t1 else t2] *)

Tactic Notation "t_cases" tactic(first) ident(c) :=
  first;
  [ Case_aux c "tvar" | Case_aux c "tapp" | Case_aux c "tabs"
  | Case_aux c "tpair" | Case_aux c "tfst" | Case_aux c "tsnd"
  | Case_aux c "ttrue" | Case_aux c "tfalse" | Case_aux c "tif" ].


(* ###################################################################### *)
(** *** Substitution *)

Fixpoint subst (x:id) (s:tm) (t:tm) : tm :=
  match t with
  | tvar y => if eq_id_dec x y then s else t
  | tabs y T t1 =>  tabs y T (if eq_id_dec x y then t1 else (subst x s t1))
  | tapp t1 t2 => tapp (subst x s t1) (subst x s t2)
  | tpair t1 t2 => tpair (subst x s t1) (subst x s t2)
  | tfst t1 => tfst (subst x s t1)
  | tsnd t1 => tsnd (subst x s t1)
  | ttrue => ttrue
  | tfalse => tfalse
  | tif t0 t1 t2 => tif (subst x s t0) (subst x s t1) (subst x s t2)
  end.

Notation "'[' x ':=' s ']' t" := (subst x s t) (at level 20).

(* ###################################################################### *)
(** *** Reduction *)

Inductive value : tm -> Prop :=
  | v_abs : forall x T11 t12,
      value (tabs x T11 t12)
  | v_pair : forall v1 v2,
      value v1 ->
      value v2 ->
      value (tpair v1 v2)
  | v_true : value ttrue
  | v_false : value tfalse
.

Hint Constructors value.

Reserved Notation "t1 '==>' t2" (at level 40).

Inductive step : tm -> tm -> Prop :=
  | ST_AppAbs : forall x T11 t12 v2,
         value v2 ->
         (tapp (tabs x T11 t12) v2) ==> [x:=v2]t12
  | ST_App1 : forall t1 t1' t2,
         t1 ==> t1' ->
         (tapp t1 t2) ==> (tapp t1' t2)
  | ST_App2 : forall v1 t2 t2',
         value v1 ->
         t2 ==> t2' ->
         (tapp v1 t2) ==> (tapp v1 t2')
  (* pairs *)
  | ST_Pair1 : forall t1 t1' t2,
        t1 ==> t1' ->
        (tpair t1 t2) ==> (tpair t1' t2)
  | ST_Pair2 : forall v1 t2 t2',
        value v1 ->
        t2 ==> t2' ->
        (tpair v1 t2) ==> (tpair v1 t2')
  | ST_Fst : forall t1 t1',
        t1 ==> t1' ->
        (tfst t1) ==> (tfst t1')
  | ST_FstPair : forall v1 v2,
        value v1 ->
        value v2 ->
        (tfst (tpair v1 v2)) ==> v1
  | ST_Snd : forall t1 t1',
        t1 ==> t1' ->
        (tsnd t1) ==> (tsnd t1')
  | ST_SndPair : forall v1 v2,
        value v1 ->
        value v2 ->
        (tsnd (tpair v1 v2)) ==> v2
  (* booleans *)
  | ST_IfTrue : forall t1 t2,
        (tif ttrue t1 t2) ==> t1
  | ST_IfFalse : forall t1 t2,
        (tif tfalse t1 t2) ==> t2
  | ST_If : forall t0 t0' t1 t2,
        t0 ==> t0' ->
        (tif t0 t1 t2) ==> (tif t0' t1 t2)

where "t1 '==>' t2" := (step t1 t2).

Tactic Notation "step_cases" tactic(first) ident(c) :=
  first;
  [ Case_aux c "ST_AppAbs" | Case_aux c "ST_App1" | Case_aux c "ST_App2"
  | Case_aux c "ST_Pair1" | Case_aux c "ST_Pair2"
    | Case_aux c "ST_Fst" | Case_aux c "ST_FstPair"
    | Case_aux c "ST_Snd" | Case_aux c "ST_SndPair"
  | Case_aux c "ST_IfTrue" | Case_aux c "ST_IfFalse" | Case_aux c "ST_If" ].

Notation multistep := (multi step).
Notation "t1 '==>*' t2" := (multistep t1 t2) (at level 40).

Hint Constructors step.

Notation step_normal_form := (normal_form step).

Lemma value__normal : forall t, value t -> step_normal_form t.
Proof with eauto.
  intros t H; induction H; intros [t' ST]; inversion ST...
Qed.


(* ###################################################################### *)
(** *** Typing *)

Definition context := partial_map ty.

Inductive has_type : context -> tm -> ty -> Prop :=
  (* Typing rules for proper terms *)
  | T_Var : forall Gamma x T,
      Gamma x = Some T ->
      has_type Gamma (tvar x) T
  | T_Abs : forall Gamma x T11 T12 t12,
      has_type (extend Gamma x T11) t12 T12 ->
      has_type Gamma (tabs x T11 t12) (TArrow T11 T12)
  | T_App : forall T1 T2 Gamma t1 t2,
      has_type Gamma t1 (TArrow T1 T2) ->
      has_type Gamma t2 T1 ->
      has_type Gamma (tapp t1 t2) T2
  (* pairs *)
  | T_Pair : forall Gamma t1 t2 T1 T2,
      has_type Gamma t1 T1 ->
      has_type Gamma t2 T2 ->
      has_type Gamma (tpair t1 t2) (TProd T1 T2)
  | T_Fst : forall Gamma t T1 T2,
      has_type Gamma t (TProd T1 T2) ->
      has_type Gamma (tfst t) T1
  | T_Snd : forall Gamma t T1 T2,
      has_type Gamma t (TProd T1 T2) ->
      has_type Gamma (tsnd t) T2
  (* booleans *)
  | T_True : forall Gamma,
      has_type Gamma ttrue TBool
  | T_False : forall Gamma,
      has_type Gamma tfalse TBool
  | T_If : forall Gamma t0 t1 t2 T,
      has_type Gamma t0 TBool ->
      has_type Gamma t1 T ->
      has_type Gamma t2 T ->
      has_type Gamma (tif t0 t1 t2) T
.

Hint Constructors has_type.

Tactic Notation "has_type_cases" tactic(first) ident(c) :=
  first;
  [ Case_aux c "T_Var" | Case_aux c "T_Abs" | Case_aux c "T_App"
  | Case_aux c "T_Pair" | Case_aux c "T_Fst" | Case_aux c "T_Snd"
  | Case_aux c "T_True" | Case_aux c "T_False" | Case_aux c "T_If" ].

Hint Extern 2 (has_type _ (tapp _ _) _) => eapply T_App; auto.
Hint Extern 2 (_ = _) => compute; reflexivity.

(* ###################################################################### *)
(** *** Context Invariance *)

Inductive appears_free_in : id -> tm -> Prop :=
  | afi_var : forall x,
      appears_free_in x (tvar x)
  | afi_app1 : forall x t1 t2,
      appears_free_in x t1 -> appears_free_in x (tapp t1 t2)
  | afi_app2 : forall x t1 t2,
      appears_free_in x t2 -> appears_free_in x (tapp t1 t2)
  | afi_abs : forall x y T11 t12,
        y <> x  ->
        appears_free_in x t12 ->
        appears_free_in x (tabs y T11 t12)
  (* pairs *)
  | afi_pair1 : forall x t1 t2,
      appears_free_in x t1 ->
      appears_free_in x (tpair t1 t2)
  | afi_pair2 : forall x t1 t2,
      appears_free_in x t2 ->
      appears_free_in x (tpair t1 t2)
  | afi_fst : forall x t,
      appears_free_in x t ->
      appears_free_in x (tfst t)
  | afi_snd : forall x t,
      appears_free_in x t ->
      appears_free_in x (tsnd t)
  (* booleans *)
  | afi_if0 : forall x t0 t1 t2,
      appears_free_in x t0 ->
      appears_free_in x (tif t0 t1 t2)
  | afi_if1 : forall x t0 t1 t2,
      appears_free_in x t1 ->
      appears_free_in x (tif t0 t1 t2)
  | afi_if2 : forall x t0 t1 t2,
      appears_free_in x t2 ->
      appears_free_in x (tif t0 t1 t2)
.

Hint Constructors appears_free_in.

Definition closed (t:tm) :=
  forall x, ~ appears_free_in x t.

Lemma context_invariance : forall Gamma Gamma' t S,
     has_type Gamma t S  ->
     (forall x, appears_free_in x t -> Gamma x = Gamma' x)  ->
     has_type Gamma' t S.
Proof with eauto.
  intros. generalize dependent Gamma'.
  has_type_cases (induction H) Case;
    intros Gamma' Heqv...
  Case "T_Var".
    apply T_Var... rewrite <- Heqv...
  Case "T_Abs".
    apply T_Abs... apply IHhas_type. intros y Hafi.
    unfold extend. destruct (eq_id_dec x y)...
  Case "T_Pair".
    apply T_Pair...
  Case "T_If".
    eapply T_If...
Qed.

Lemma free_in_context : forall x t T Gamma,
   appears_free_in x t ->
   has_type Gamma t T ->
   exists T', Gamma x = Some T'.
Proof with eauto.
  intros x t T Gamma Hafi Htyp.
  has_type_cases (induction Htyp) Case; inversion Hafi; subst...
  Case "T_Abs".
    destruct IHHtyp as [T' Hctx]... exists T'.
    unfold extend in Hctx.
    rewrite neq_id in Hctx...
Qed.

Corollary typable_empty__closed : forall t T,
    has_type empty t T  ->
    closed t.
Proof.
  intros. unfold closed. intros x H1.
  destruct (free_in_context _ _ _ _ H1 H) as [T' C].
  inversion C.  Qed.

(* ###################################################################### *)
(** *** Preservation *)

Lemma substitution_preserves_typing : forall Gamma x U v t S,
     has_type (extend Gamma x U) t S  ->
     has_type empty v U   ->
     has_type Gamma ([x:=v]t) S.
Proof with eauto.
  (* Theorem: If Gamma,x:U |- t : S and empty |- v : U, then
     Gamma |- ([x:=v]t) S. *)
  intros Gamma x U v t S Htypt Htypv.
  generalize dependent Gamma. generalize dependent S.
  (* Proof: By induction on the term t.  Most cases follow directly
     from the IH, with the exception of tvar and tabs.
     The former aren't automatic because we must reason about how the
     variables interact. *)
  t_cases (induction t) Case;
    intros S Gamma Htypt; simpl; inversion Htypt; subst...
  Case "tvar".
    simpl. rename i into y.
    (* If t = y, we know that
         [empty |- v : U] and
         [Gamma,x:U |- y : S]
       and, by inversion, [extend Gamma x U y = Some S].  We want to
       show that [Gamma |- [x:=v]y : S].

       There are two cases to consider: either [x=y] or [x<>y]. *)
    destruct (eq_id_dec x y).
    SCase "x=y".
    (* If [x = y], then we know that [U = S], and that [[x:=v]y = v].
       So what we really must show is that if [empty |- v : U] then
       [Gamma |- v : U].  We have already proven a more general version
       of this theorem, called context invariance. *)
      subst.
      unfold extend in H1. rewrite eq_id in H1.
      inversion H1; subst. clear H1.
      eapply context_invariance...
      intros x Hcontra.
      destruct (free_in_context _ _ S empty Hcontra) as [T' HT']...
      inversion HT'.
    SCase "x<>y".
    (* If [x <> y], then [Gamma y = Some S] and the substitution has no
       effect.  We can show that [Gamma |- y : S] by [T_Var]. *)
      apply T_Var... unfold extend in H1. rewrite neq_id in H1...
  Case "tabs".
    rename i into y. rename t into T11.
    (* If [t = tabs y T11 t0], then we know that
         [Gamma,x:U |- tabs y T11 t0 : T11->T12]
         [Gamma,x:U,y:T11 |- t0 : T12]
         [empty |- v : U]
       As our IH, we know that forall S Gamma,
         [Gamma,x:U |- t0 : S -> Gamma |- [x:=v]t0 S].

       We can calculate that
         [x:=v]t = tabs y T11 (if beq_id x y then t0 else [x:=v]t0)
       And we must show that [Gamma |- [x:=v]t : T11->T12].  We know
       we will do so using [T_Abs], so it remains to be shown that:
         [Gamma,y:T11 |- if beq_id x y then t0 else [x:=v]t0 : T12]
       We consider two cases: [x = y] and [x <> y].
    *)
    apply T_Abs...
    destruct (eq_id_dec x y).
    SCase "x=y".
    (* If [x = y], then the substitution has no effect.  Context
       invariance shows that [Gamma,y:U,y:T11] and [Gamma,y:T11] are
       equivalent.  Since the former context shows that [t0 : T12], so
       does the latter. *)
      eapply context_invariance...
      subst.
      intros x Hafi. unfold extend.
      destruct (eq_id_dec y x)...
    SCase "x<>y".
    (* If [x <> y], then the IH and context invariance allow us to show that
         [Gamma,x:U,y:T11 |- t0 : T12]       =>
         [Gamma,y:T11,x:U |- t0 : T12]       =>
         [Gamma,y:T11 |- [x:=v]t0 : T12] *)
      apply IHt. eapply context_invariance...
      intros z Hafi. unfold extend.
      destruct (eq_id_dec y z)...
      subst. rewrite neq_id...
Qed.

Theorem preservation : forall t t' T,
     has_type empty t T  ->
     t ==> t'  ->
     has_type empty t' T.
Proof with eauto.
  intros t t' T HT.
  (* Theorem: If [empty |- t : T] and [t ==> t'], then [empty |- t' : T]. *)
  remember (@empty ty) as Gamma. generalize dependent HeqGamma.
  generalize dependent t'.
  (* Proof: By induction on the given typing derivation.  Many cases are
     contradictory ([T_Var], [T_Abs]).  We show just the interesting ones. *)
  has_type_cases (induction HT) Case;
    intros t' HeqGamma HE; subst; inversion HE; subst...
  Case "T_App".
    (* If the last rule used was [T_App], then [t = t1 t2], and three rules
       could have been used to show [t ==> t']: [ST_App1], [ST_App2], and
       [ST_AppAbs]. In the first two cases, the result follows directly from
       the IH. *)
    inversion HE; subst...
    SCase "ST_AppAbs".
      (* For the third case, suppose
           [t1 = tabs x T11 t12]
         and
           [t2 = v2].
         We must show that [empty |- [x:=v2]t12 : T2].
         We know by assumption that
             [empty |- tabs x T11 t12 : T1->T2]
         and by inversion
             [x:T1 |- t12 : T2]
         We have already proven that substitution_preserves_typing and
             [empty |- v2 : T1]
         by assumption, so we are done. *)
      apply substitution_preserves_typing with T1...
      inversion HT1...
  Case "T_Fst".
    inversion HT...
  Case "T_Snd".
    inversion HT...
Qed.
(** [] *)


(* ###################################################################### *)
(** *** Determinism *)
Hint Extern 2 (_ = _) =>
match goal with
    | H: value ?x, H0: ?x ==> _ |- _
      => (apply value__normal in H; contradiction H; eauto)
end.

Lemma step_deterministic :
   deterministic step.
Proof with eauto.
   unfold deterministic.
   intros. generalize dependent y2.
   induction H; intros.
   inversion H0; subst; try solve by inversion...
   inversion H0; subst; try solve by inversion...
   apply IHstep in H4. subst...
   inversion H1; subst; try solve by inversion...
   apply IHstep in H6. subst...
   inversion H0; subst...
   apply IHstep in H4. subst...
   inversion H1; subst...
   apply IHstep in H6. subst...
   inversion H0; subst.
   apply IHstep in H2. subst...
   inversion H0; subst.
   apply IHstep in H4. subst...
   inversion H; subst...
   inversion H1; subst... inversion H3...
   inversion H0; subst.
   apply IHstep in H2. subst...
   inversion H0; subst.
   apply IHstep in H4. subst...
   inversion H; subst...
   inversion H1; subst... inversion H3...
   inversion H0; subst... inversion H4.
   inversion H0; subst... inversion H4.
   inversion H0; subst; try solve by inversion.
   apply IHstep in H5. subst...
Qed.


(* ###################################################################### *)
(** * Normalization *)

(** Now for the actual normalization proof.

    Our goal is to prove that every well-typed term evaluates to a
    normal form.  In fact, it turns out to be convenient to prove
    something slightly stronger, namely that every well-typed term
    evaluates to a _value_.  This follows from the weaker property
    anyway via the Progress lemma (why?) but otherwise we don't need
    Progress, and we didn't bother re-proving it above.

    Here's the key definition: *)

Definition halts  (t:tm) : Prop :=  exists t', t ==>* t' /\  value t'.

(** A trivial fact: *)

Lemma value_halts : forall v, value v -> halts v.
Proof.
  intros v H. unfold halts.
  exists v. split.
  apply multi_refl.
  assumption.
Qed.

(** The key issue in the normalization proof (as in many proofs by
induction) is finding a strong enough induction hypothesis.  To this
end, we begin by defining, for each type [T], a set [R_T] of closed
terms of type [T].  We will specify these sets using a relation [R]
and write [R T t] when [t] is in [R_T]. (The sets [R_T] are sometimes
called _saturated sets_ or _reducibility candidates_.)

Here is the definition of [R] for the base language:

- [R bool t] iff [t] is a closed term of type [bool] and [t] halts in a value

- [R (T1 -> T2) t] iff [t] is a closed term of type [T1 -> T2] and [t] halts
  in a value _and_ for any term [s] such that [R T1 s], we have [R
  T2 (t s)]. *)

(** This definition gives us the strengthened induction hypothesis that we
need.  Our primary goal is to show that all _programs_ ---i.e., all
closed terms of base type---halt.  But closed terms of base type can
contain subterms of functional type, so we need to know something
about these as well.  Moreover, it is not enough to know that these
subterms halt, because the application of a normalized function to a
normalized argument involves a substitution, which may enable more
evaluation steps.  So we need a stronger condition for terms of
functional type: not only should they halt themselves, but, when
applied to halting arguments, they should yield halting results.

The form of [R] is characteristic of the _logical relations_ proof
technique.  (Since we are just dealing with unary relations here, we
could perhaps more properly say _logical predicates_.)  If we want to
prove some property [P] of all closed terms of type [A], we proceed by
proving, by induction on types, that all terms of type [A] _possess_
property [P], all terms of type [A->A] _preserve_ property [P], all
terms of type [(A->A)->(A->A)] _preserve the property of preserving_
property [P], and so on.  We do this by defining a family of
predicates, indexed by types.  For the base type [A], the predicate is
just [P].  For functional types, it says that the function should map
values satisfying the predicate at the input type to values satisfying
the predicate at the output type.

When we come to formalize the definition of [R] in Coq, we hit a
problem.  The most obvious formulation would be as a parameterized
Inductive proposition like this:

Inductive R : ty -> tm -> Prop :=
| R_bool : forall b t, has_type empty t TBool ->
                halts t ->
                R TBool t
| R_arrow : forall T1 T2 t, has_type empty t (TArrow T1 T2) ->
                halts t ->
                (forall s, R T1 s -> R T2 (tapp t s)) ->
                R (TArrow T1 T2) t.

Unfortunately, Coq rejects this definition because it violates the
_strict positivity requirement_ for inductive definitions, which says
that the type being defined must not occur to the left of an arrow in
the type of a constructor argument. Here, it is the third argument to
[R_arrow], namely [(forall s, R T1 s -> R TS (tapp t s))], and
specifically the [R T1 s] part, that violates this rule.  (The
outermost arrows separating the constructor arguments don't count when
applying this rule; otherwise we could never have genuinely inductive
predicates at all!)  The reason for the rule is that types defined
with non-positive recursion can be used to build non-terminating
functions, which as we know would be a disaster for Coq's logical
soundness. Even though the relation we want in this case might be
perfectly innocent, Coq still rejects it because it fails the
positivity test.

Fortunately, it turns out that we _can_ define [R] using a
[Fixpoint]: *)

Fixpoint R (T:ty) (t:tm) {struct T} : Prop :=
  has_type empty t T /\ halts t /\
  (match T with
   | TBool  => True
   | TArrow T1 T2 => (forall s, R T1 s -> R T2 (tapp t s))
   | TProd T1 T2 => (exists s1 s2, t ==>* tpair s1 s2 /\
                             R T1 s1 /\ R T2 s2)
   end).

(** As immediate consequences of this definition, we have that every
element of every set [R_T] halts in a value and is closed with type
[t] :*)

Lemma R_halts : forall {T} {t}, R T t -> halts t.
Proof.
  intros. destruct T; unfold R in H; inversion H; inversion H1;  assumption.
Qed.


Lemma R_typable_empty : forall {T} {t}, R T t -> has_type empty t T.
Proof.
  intros. destruct T; unfold R in H; inversion H; inversion H1; assumption.
Qed.

(** Now we proceed to show the main result, which is that every
well-typed term of type [T] is an element of [R_T].  Together with
[R_halts], that will show that every well-typed term halts in a
value.  *)


(* ###################################################################### *)
(** **  Membership in [R_T] is invariant under evaluation *)

(** We start with a preliminary lemma that shows a kind of strong
preservation property, namely that membership in [R_T] is _invariant_
under evaluation. We will need this property in both directions,
i.e. both to show that a term in [R_T] stays in [R_T] when it takes a
forward step, and to show that any term that ends up in [R_T] after a
step must have been in [R_T] to begin with.

First of all, an easy preliminary lemma. Note that in the forward
direction the proof depends on the fact that our language is
determinstic. This lemma might still be true for non-deterministic
languages, but the proof would be harder! *)

Lemma step_preserves_halting : forall t t', (t ==> t') -> (halts t <-> halts t').
Proof.
 intros t t' ST.  unfold halts.
 split.
 Case "->".
  intros [t'' [STM V]].
  inversion STM; subst.
   apply ex_falso_quodlibet.  apply value__normal in V. unfold normal_form in V. apply V. exists t'. auto.
   rewrite (step_deterministic _ _ _ ST H). exists t''. split; assumption.
 Case "<-".
  intros [t'0 [STM V]].
  exists t'0. split; eauto.
Qed.

(** Now the main lemma, which comes in two parts, one for each
   direction.  Each proceeds by induction on the structure of the type
   [T]. In fact, this is where we make fundamental use of the
   structure of types.

   One requirement for staying in [R_T] is to stay in type [T]. In the
   forward direction, we get this from ordinary type Preservation. *)

Lemma step_preserves_R : forall T t t', (t ==> t') -> R T t -> R T t'.
Proof.
 induction T;  intros t t' E Rt; unfold R; fold R; unfold R in Rt; fold R in Rt;
               destruct Rt as [typable_empty_t [halts_t RRt]].
  (* TBool *)
  split. eapply preservation; eauto.
  split. apply (step_preserves_halting _ _ E); eauto.
  auto.
  (* TArrow *)
  split. eapply preservation; eauto.
  split. apply (step_preserves_halting _ _ E); eauto.
  intros.
  eapply IHT2.
  apply  ST_App1. apply E.
  apply RRt; auto.
  destruct RRt as [s1 [s2 [H0 [H1 H2]]]].
  inversion H0; subst. inversion E; subst;
  split; try eapply preservation; eauto;
  split; try apply (step_preserves_halting _ _ E); eauto.
  exists t1'; eauto.
  exists s1; eauto.
  assert (t' = y) by (eapply step_deterministic; eauto).
  subst. split. eapply preservation; eauto.
  split. apply (step_preserves_halting _ _ E); eauto.
  exists s1; eauto.
Qed.


(** The generalization to multiple steps is trivial: *)

Lemma multistep_preserves_R : forall T t t',
  (t ==>* t') -> R T t -> R T t'.
Proof.
  intros T t t' STM; induction STM; intros.
  assumption.
  apply IHSTM. eapply step_preserves_R. apply H. assumption.
Qed.

(** In the reverse direction, we must add the fact that [t] has type
   [T] before stepping as an additional hypothesis. *)

Lemma step_preserves_R' : forall T t t',
  has_type empty t T -> (t ==> t') -> R T t' -> R T t.
Proof with eauto.
 induction T;  intros t t' Ha E Rt; unfold R; fold R; unfold R in Rt;
 fold R in Rt; destruct Rt as [typable_empty_t [halts_t RRt]]; split...
 split... eapply step_preserves_halting...
 split. eapply step_preserves_halting... intros.
 remember H. clear Heqr.
 apply R_typable_empty in H.
 apply RRt in r. eapply IHT2...
 destruct RRt as [s1 [s2 [H1 [H2 H3]]]].
 split. eapply step_preserves_halting...
 inversion H1; subst; exists s1...
Qed.

Lemma multistep_preserves_R' : forall T t t',
  has_type empty t T -> (t ==>* t') -> R T t' -> R T t.
Proof.
  intros T t t' HT STM.
  induction STM; intros.
    assumption.
    eapply step_preserves_R'.  assumption. apply H. apply IHSTM.
    eapply preservation;  eauto. auto.
Qed.

(* ###################################################################### *)
(** ** Closed instances of terms of type [T] belong to [R_T] *)

(** Now we proceed to show that every term of type [T] belongs to
[R_T].  Here, the induction will be on typing derivations (it would be
surprising to see a proof about well-typed terms that did not
somewhere involve induction on typing derivations!).  The only
technical difficulty here is in dealing with the abstraction case.
Since we are arguing by induction, the demonstration that a term
[tabs x T1 t2] belongs to [R_(T1->T2)] should involve applying the
induction hypothesis to show that [t2] belongs to [R_(T2)].  But
[R_(T2)] is defined to be a set of _closed_ terms, while [t2] may
contain [x] free, so this does not make sense.

This problem is resolved by using a standard trick to suitably
generalize the induction hypothesis: instead of proving a statement
involving a closed term, we generalize it to cover all closed
_instances_ of an open term [t].  Informally, the statement of the
lemma will look like this:

If [x1:T1,..xn:Tn |- t : T] and [v1,...,vn] are values such that
[R T1 v1], [R T2 v2], ..., [R Tn vn], then
[R T ([x1:=v1][x2:=v2]...[xn:=vn]t)].

The proof will proceed by induction on the typing derivation
[x1:T1,..xn:Tn |- t : T]; the most interesting case will be the one
for abstraction. *)

(* ###################################################################### *)
(** *** Multisubstitutions, multi-extensions, and instantiations *)

(** However, before we can proceed to formalize the statement and
proof of the lemma, we'll need to build some (rather tedious)
machinery to deal with the fact that we are performing _multiple_
substitutions on term [t] and _multiple_ extensions of the typing
context.  In particular, we must be precise about the order in which
the substitutions occur and how they act on each other.  Often these
details are simply elided in informal paper proofs, but of course Coq
won't let us do that. Since here we are substituting closed terms, we
don't need to worry about how one substitution might affect the term
put in place by another.  But we still do need to worry about the
_order_ of substitutions, because it is quite possible for the same
identifier to appear multiple times among the [x1,...xn] with
different associated [vi] and [Ti].

To make everything precise, we will assume that environments are
extended from left to right, and multiple substitutions are performed
from right to left.  To see that this is consistent, suppose we have
an environment written as [...,y:bool,...,y:nat,...]  and a
corresponding term substitution written as [...[y:=(tbool
true)]...[y:=(tnat 3)]...t].  Since environments are extended from
left to right, the binding [y:nat] hides the binding [y:bool]; since
substitutions are performed right to left, we do the substitution
[y:=(tnat 3)] first, so that the substitution [y:=(tbool true)] has
no effect. Substitution thus correctly preserves the type of the term.

With these points in mind, the following definitions should make sense.

A _multisubstitution_ is the result of applying a list of
substitutions, which we call an _environment_. *)

Definition env := list (id * tm).

Fixpoint msubst (ss:env) (t:tm) {struct ss} : tm :=
match ss with
| nil => t
| ((x,s)::ss') => msubst ss' ([x:=s]t)
end.

(** We need similar machinery to talk about repeated extension of a
    typing context using a list of (identifier, type) pairs, which we
    call a _type assignment_. *)

Definition tass := list (id * ty).

Fixpoint mextend (Gamma : context) (xts : tass) :=
  match xts with
  | nil => Gamma
  | ((x,v)::xts') => extend (mextend Gamma xts') x v
  end.

(** We will need some simple operations that work uniformly on
environments and type assigments *)

Fixpoint lookup {X:Set} (k : id) (l : list (id * X)) {struct l} : option X :=
  match l with
    | nil => None
    | (j,x) :: l' =>
      if eq_id_dec j k then Some x else lookup k l'
  end.

Fixpoint drop {X:Set} (n:id) (nxs:list (id * X)) {struct nxs} : list (id * X) :=
  match nxs with
    | nil => nil
    | ((n',x)::nxs') => if eq_id_dec n' n then drop n nxs' else (n',x)::(drop n nxs')
  end.

(** An _instantiation_ combines a type assignment and a value
   environment with the same domains, where corresponding elements are
   in R *)

Inductive instantiation :  tass -> env -> Prop :=
| V_nil : instantiation nil nil
| V_cons : forall x T v c e, value v -> R T v -> instantiation c e -> instantiation ((x,T)::c) ((x,v)::e).


(** We now proceed to prove various properties of these definitions. *)

(* ###################################################################### *)
(** *** More Substitution Facts *)

(** First we need some additional lemmas on (ordinary) substitution. *)

Lemma vacuous_substitution : forall  t x,
     ~ appears_free_in x t  ->
     forall t', [x:=t']t = t.
Proof with eauto.
  intros. induction t;
    try (simpl; assert ([x := t']t = t); eauto; rewrite H0);
    try (assert ([x := t']t1 = t1); eauto;
         assert ([x := t']t2 = t2); eauto;
         simpl; rewrite H0; rewrite H1; eauto)...
  destruct (eq_id_dec x i). subst.
  contradiction H... unfold subst. rewrite neq_id...
  simpl. destruct (eq_id_dec x i)...
  assert ([x := t']t0 = t0)... rewrite H0...
  assert ([x := t']t3 = t3)...
  rewrite H2...
Qed.

Lemma subst_closed: forall t,
     closed t  ->
     forall x t', [x:=t']t = t.
Proof.
  intros. apply vacuous_substitution. apply H.  Qed.


Lemma subst_not_afi : forall t x v, closed v ->  ~ appears_free_in x ([x:=v]t).
Proof with eauto.  (* rather slow this way *)
  unfold closed, not.
  t_cases (induction t) Case; intros x v P A; simpl in A.
    Case "tvar".
     destruct (eq_id_dec x i)...
       inversion A; subst. auto.
    Case "tapp".
     inversion A; subst...
    Case "tabs".
     destruct (eq_id_dec x i)...
       inversion A; subst...
       inversion A; subst...
    Case "tpair".
     inversion A; subst...
    Case "tfst".
     inversion A; subst...
    Case "tsnd".
     inversion A; subst...
    Case "ttrue".
     inversion A.
    Case "tfalse".
     inversion A.
    Case "tif".
     inversion A; subst...
Qed.


Lemma duplicate_subst : forall t' x t v,
  closed v -> [x:=t]([x:=v]t') = [x:=v]t'.
Proof.
  intros. eapply vacuous_substitution. apply subst_not_afi.  auto.
Qed.

Lemma swap_subst : forall t x x1 v v1, x <> x1 -> closed v -> closed v1 ->
                   [x1:=v1]([x:=v]t) = [x:=v]([x1:=v1]t).
Proof with eauto.
 t_cases (induction t) Case; intros; simpl...
  Case "tvar".
   destruct (eq_id_dec x i); destruct (eq_id_dec x1 i).
      subst. apply ex_falso_quodlibet...
      subst. simpl. rewrite eq_id. apply subst_closed...
      subst. simpl. rewrite eq_id. rewrite subst_closed...
      simpl. rewrite neq_id... rewrite neq_id...
  Case "tapp".
    rewrite (IHt1 _ _ _ _ H H0 H1).
    rewrite (IHt2 _ _ _ _ H H0 H1)...
  Case "tabs".
   destruct (eq_id_dec x i); destruct (eq_id_dec x1 i)...
    rewrite (IHt _ _ _ _ H H0 H1)...
  Case "tpair".
    rewrite (IHt1 _ _ _ _ H H0 H1).
    rewrite (IHt2 _ _ _ _ H H0 H1)...
  Case "tfst".
    rewrite (IHt _ _ _ _ H H0 H1)...
  Case "tsnd".
    rewrite (IHt _ _ _ _ H H0 H1)...
  Case "tif".
    rewrite (IHt1 _ _ _ _ H H0 H1).
    rewrite (IHt2 _ _ _ _ H H0 H1).
    rewrite (IHt3 _ _ _ _ H H0 H1)...
Qed.

(* ###################################################################### *)
(** *** Properties of multi-substitutions *)

Lemma msubst_closed: forall t, closed t -> forall ss, msubst ss t = t.
Proof.
  induction ss.
    reflexivity.
    destruct a. simpl. rewrite subst_closed; assumption.
Qed.

(** Closed environments are those that contain only closed terms. *)

Fixpoint closed_env (env:env) {struct env} :=
match env with
| nil => True
| (x,t)::env' => closed t /\ closed_env env'
end.

(** Next come a series of lemmas charcterizing how [msubst] of closed terms
    distributes over [subst] and over each term form *)

Lemma subst_msubst: forall env x v t, closed v -> closed_env env ->
  msubst env ([x:=v]t) = [x:=v](msubst (drop x env) t).
Proof.
  induction env0; intros.
    auto.
    destruct a. simpl.
    inversion H0. fold closed_env in H2.
    destruct (eq_id_dec i x).
      subst. rewrite duplicate_subst; auto.
      simpl. rewrite swap_subst; eauto.
Qed.


Lemma msubst_var:  forall ss x, closed_env ss ->
   msubst ss (tvar x) =
   match lookup x ss with
   | Some t => t
   | None => tvar x
  end.
Proof.
  induction ss; intros.
    reflexivity.
    destruct a.
     simpl. destruct (eq_id_dec i x).
      apply msubst_closed. inversion H; auto.
      apply IHss. inversion H; auto.
Qed.

Lemma msubst_abs: forall ss x T t,
  msubst ss (tabs x T t) = tabs x T (msubst (drop x ss) t).
Proof.
  induction ss; intros.
    reflexivity.
    destruct a.
      simpl. destruct (eq_id_dec i x); simpl; auto.
Qed.

Lemma msubst_app : forall ss t1 t2, msubst ss (tapp t1 t2) = tapp (msubst ss t1) (msubst ss t2).
Proof.
 induction ss; intros.
   reflexivity.
   destruct a.
    simpl. rewrite <- IHss. auto.
Qed.

(** You'll need similar functions for the other term constructors. *)

Lemma msubst_pair : forall ss t1 t2, msubst ss (tpair t1 t2)
                                = tpair (msubst ss t1) (msubst ss t2).
Proof.
 induction ss; intros.
   reflexivity.
   destruct a.
    simpl. rewrite <- IHss. auto.
Qed.

Lemma msubst_fst : forall ss t,
  msubst ss (tfst t) = tfst (msubst ss t).
Proof with eauto.
  induction ss... intros.
  destruct a.
  simpl. rewrite IHss...
Qed.

Lemma msubst_snd : forall ss t,
  msubst ss (tsnd t) = tsnd (msubst ss t).
Proof with eauto.
  induction ss... intros.
  destruct a.
  simpl. rewrite IHss...
Qed.

Lemma msubst_true : forall ss,
  msubst ss ttrue = ttrue.
Proof with eauto.
  induction ss... intros.
  destruct a.
  simpl. rewrite IHss...
Qed.

Lemma msubst_false : forall ss,
  msubst ss tfalse = tfalse.
Proof with eauto.
  induction ss... intros.
  destruct a.
  simpl. rewrite IHss...
Qed.

Lemma msubst_if : forall ss t1 t2 t3,
  msubst ss (tif t1 t2 t3) = tif (msubst ss t1) (msubst ss t2) (msubst ss t3).
Proof with eauto.
  induction ss... intros.
  destruct a. simpl. rewrite IHss...
Qed.
(* ###################################################################### *)
(** *** Properties of multi-extensions *)

(** We need to connect the behavior of type assignments with that of their
   corresponding contexts. *)

Lemma mextend_lookup : forall (c : tass) (x:id), lookup x c = (mextend empty c) x.
Proof.
  induction c; intros.
    auto.
    destruct a. unfold lookup, mextend, extend. destruct (eq_id_dec i x); auto.
Qed.

Lemma mextend_drop : forall (c: tass) Gamma x x',
       mextend Gamma (drop x c) x' = if eq_id_dec x x' then Gamma x' else mextend Gamma c x'.
   induction c; intros.
      destruct (eq_id_dec x x'); auto.
      destruct a. simpl.
      destruct (eq_id_dec i x).
         subst. rewrite IHc.
            destruct (eq_id_dec x x').  auto. unfold extend. rewrite neq_id; auto.
         simpl. unfold extend.  destruct (eq_id_dec i x').
            subst.
               destruct (eq_id_dec x x').
                  subst. exfalso. auto.
                  auto.
           auto.
Qed.


(* ###################################################################### *)
(** *** Properties of Instantiations *)

(** These are strightforward. *)

Lemma instantiation_domains_match: forall {c} {e},
  instantiation c e -> forall {x} {T}, lookup x c = Some T -> exists t, lookup x e = Some t.
Proof.
  intros c e V. induction V; intros x0 T0 C.
    solve by inversion .
    simpl in *.
    destruct (eq_id_dec x x0); eauto.
Qed.

Lemma instantiation_env_closed : forall c e,  instantiation c e -> closed_env e.
Proof.
  intros c e V; induction V; intros.
    econstructor.
    unfold closed_env. fold closed_env.
    split.  eapply typable_empty__closed. eapply R_typable_empty. eauto.
        auto.
Qed.

Lemma instantiation_R : forall c e, instantiation c e ->
                        forall x t T, lookup x c = Some T ->
                                      lookup x e = Some t -> R T t.
Proof.
  intros c e V. induction V; intros x' t' T' G E.
    solve by inversion.
    unfold lookup in *.  destruct (eq_id_dec x x').
      inversion G; inversion E; subst.  auto.
      eauto.
Qed.

Lemma instantiation_drop : forall c env,
  instantiation c env -> forall x, instantiation (drop x c) (drop x env).
Proof.
  intros c e V. induction V.
    intros.  simpl.  constructor.
    intros. unfold drop. destruct (eq_id_dec x x0); auto. constructor; eauto.
Qed.


(* ###################################################################### *)
(** *** Congruence lemmas on multistep *)

(** We'll need just a few of these; add them as the demand arises. *)

Lemma multistep_App2 : forall v t t',
  value v -> (t ==>* t') -> (tapp v t) ==>* (tapp v t').
Proof.
  intros v t t' V STM. induction STM.
   apply multi_refl.
   eapply multi_step.
     apply ST_App2; eauto.  auto.
Qed.

Lemma multistep_Pair1 : forall t1 t2 v,
  t1 ==>* v -> (tpair t1 t2) ==>* (tpair v t2).
Proof with eauto.
  intros. induction H...
Qed.

Lemma multistep_Pair2 : forall v t t',
  value v -> (t ==>* t') -> (tpair v t) ==>* (tpair v t').
Proof with eauto.
  intros. induction H0...
Qed.

Lemma multistep_Fst : forall t t',
  t ==>* t' -> (tfst t ==>* tfst t').
Proof with eauto.
  intros. induction H...
Qed.

Lemma multistep_Snd : forall t t',
  t ==>* t' -> (tsnd t ==>* tsnd t').
Proof with eauto.
  intros. induction H...
Qed.

Lemma multistep_If : forall t1 t1' t2 t3,
  t1 ==>* t1' -> tif t1 t2 t3 ==>* tif t1' t2 t3.
Proof with eauto.
  intros. induction H...
Qed.

(* ###################################################################### *)
(** *** The R Lemma. *)

(** We finally put everything together.

    The key lemma about preservation of typing under substitution can
    be lifted to multi-substitutions: *)

Lemma msubst_preserves_typing : forall c e,
     instantiation c e ->
     forall Gamma t S, has_type (mextend Gamma c) t S ->
     has_type Gamma (msubst e t) S.
Proof.
  induction 1; intros.
    simpl in H. simpl. auto.
    simpl in H2.  simpl.
    apply IHinstantiation.
    eapply substitution_preserves_typing; eauto.
    apply (R_typable_empty H0).
Qed.

(** And at long last, the main lemma. *)

Lemma msubst_R : forall c env t T,
  has_type (mextend empty c) t T -> instantiation c env -> R T (msubst env t).
Proof.
  intros c env0 t T HT V.
  generalize dependent env0.
  (* We need to generalize the hypothesis a bit before setting up the induction. *)
  remember (mextend empty c) as Gamma.
  assert (forall x, Gamma x = lookup x c).
    intros. rewrite HeqGamma. rewrite mextend_lookup. auto.
  clear HeqGamma.
  generalize dependent c.
  has_type_cases (induction HT) Case; intros.

  Case "T_Var".
   rewrite H0 in H. destruct (instantiation_domains_match V H) as [t P].
   eapply instantiation_R; eauto.
   rewrite msubst_var.  rewrite P. auto. eapply instantiation_env_closed; eauto.

  Case "T_Abs".
    rewrite msubst_abs.
    (* We'll need variants of the following fact several times, so its simplest to
       establish it just once. *)
    assert (WT: has_type empty (tabs x T11 (msubst (drop x env0) t12)) (TArrow T11 T12)).
     eapply T_Abs. eapply msubst_preserves_typing.  eapply instantiation_drop; eauto.
      eapply context_invariance.  apply HT.
      intros.
      unfold extend. rewrite mextend_drop. destruct (eq_id_dec x x0). auto.
        rewrite H.
          clear - c n. induction c.
              simpl.  rewrite neq_id; auto.
              simpl. destruct a.  unfold extend. destruct (eq_id_dec i x0); auto.
    unfold R. fold R. split.
       auto.
     split. apply value_halts. apply v_abs.
     intros.
     destruct (R_halts H0) as [v [P Q]].
     pose proof (multistep_preserves_R _ _ _ P H0).
     apply multistep_preserves_R' with (msubst ((x,v)::env0) t12).
       eapply T_App. eauto.
       apply R_typable_empty; auto.
       eapply multi_trans.  eapply multistep_App2; eauto.
       eapply multi_R.
       simpl.  rewrite subst_msubst.
       eapply ST_AppAbs; eauto.
       eapply typable_empty__closed.
       apply (R_typable_empty H1).
       eapply instantiation_env_closed; eauto.
       eapply (IHHT ((x,T11)::c)).
          intros. unfold extend, lookup. destruct (eq_id_dec x x0); auto.
       constructor; auto.

  Case "T_App".
    rewrite msubst_app.
    destruct (IHHT1 c H env0 V) as [_ [_ P1]].
    pose proof (IHHT2 c H env0 V) as P2. fold R in P1.  auto.
  Case "T_Pair".
    rewrite msubst_pair.
    pose proof (IHHT1 c H env0 V). pose proof (IHHT2 c H env0 V).
    unfold R. fold R. split. apply T_Pair; apply R_typable_empty; auto.
    destruct (R_halts H0) as [v1 [H11 H12]].
    destruct (R_halts H1) as [v2 [H21 H22]].
    assert (tpair (msubst env0 t1) (msubst env0 t2) ==>* tpair v1 v2).
      eapply multi_trans.
        apply multistep_Pair1. apply H11.
        apply multistep_Pair2. auto. apply H21.
    split. exists (tpair v1 v2). auto.
    exists v1. exists v2. split. auto.
    split.
      eapply multistep_preserves_R. apply H11. auto.
      eapply multistep_preserves_R. apply H21. auto.
  Case "T_Fst".
    rewrite msubst_fst. pose proof (IHHT c H env0 V).
    destruct H0 as [HT' [halts [s1 [s2 [STM [R_s1 R_s2]]]]]].
    destruct (R_halts R_s1) as [v1 [H11 H12]].
    destruct (R_halts R_s2) as [v2 [H21 H22]].
    assert (tfst (msubst env0 t) ==>* v1).
    apply multi_trans with (tfst (tpair v1 v2)); eauto.
    apply multistep_Fst.
    apply multi_trans with (tpair s1 s2); auto.
    apply multi_trans with (tpair v1 s2).
    apply multistep_Pair1; auto.
    apply multistep_Pair2; auto.
    assert (R T1 v1). apply multistep_preserves_R with s1; eauto.
    apply multistep_preserves_R' with v1; eauto.
  Case "T_Snd".
    rewrite msubst_snd. pose proof (IHHT c H env0 V).
    destruct H0 as [HT' [halts [s1 [s2 [STM [R_s1 R_s2]]]]]].
    destruct (R_halts R_s1) as [v1 [H11 H12]].
    destruct (R_halts R_s2) as [v2 [H21 H22]].
    assert (tsnd (msubst env0 t) ==>* v2).
    apply multi_trans with (tsnd (tpair v1 v2)); eauto.
    apply multistep_Snd.
    apply multi_trans with (tpair s1 s2); auto.
    apply multi_trans with (tpair v1 s2).
    apply multistep_Pair1; auto.
    apply multistep_Pair2; auto.
    assert (R T2 v2). apply multistep_preserves_R with s2; eauto.
    apply multistep_preserves_R' with v2; eauto.
  Case "T_True".
    rewrite msubst_true. unfold R. split; auto.
    split. apply value_halts. auto.
    auto.
  Case "T_False".
    rewrite msubst_false. unfold R. split; auto.
    split. apply value_halts. auto.
    auto.
  Case "T_If".
    rewrite msubst_if.
    destruct (IHHT1 c H env0 V) as [HT [Halts _]].
    pose proof (IHHT1 c H env0 V).
    pose proof (IHHT2 c H env0 V).
    pose proof (IHHT3 c H env0 V).
    destruct Halts as [bool [STM value]].
    assert (has_type empty (tif (msubst env0 t0) (msubst env0 t1) (msubst env0 t2)) T).
    apply T_If. auto. apply (R_typable_empty H1). apply (R_typable_empty H2).
    eapply multistep_preserves_R'. auto.
    apply multistep_If. apply STM.
    assert (has_type \empty bool TBool).
    apply R_typable_empty.
    apply multistep_preserves_R with (msubst env0 t0); eauto.
    destruct bool; try solve by inversion.
    eapply step_preserves_R'.
    apply T_If. auto. apply (R_typable_empty H1). apply (R_typable_empty H2).
    apply ST_IfTrue.
    auto.
    eapply step_preserves_R'.
    apply T_If. auto. apply (R_typable_empty H1). apply (R_typable_empty H2).
    apply ST_IfFalse.
    auto.
Qed.
(* ###################################################################### *)
(** *** Normalization Theorem *)

Theorem normalization : forall t T, has_type empty t T -> halts t.
Proof.
  intros.
  replace t with (msubst nil t) by reflexivity.
  apply (@R_halts T).
  apply (msubst_R nil); eauto.
  eapply V_nil.
Qed.

(** $Date: 2014-12-31 11:17:56 -0500 (Wed, 31 Dec 2014) $ *)
