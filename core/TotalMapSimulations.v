Require Import List.
Import ListNotations.

Require Import Arith.
Require Import ZArith.
Require Import Omega.

Require Import StructTact.StructTactics.
Require Import HandlerMonad.
Require Import Net.
Require Import StructTact.Util.

Require Import UpdateLemmas.
Local Arguments update {_} {_} {_} _ _ _ _ : simpl never.

Require Import FunctionalExtensionality.
Require Import Sumbool.
Require Import Sorting.Permutation.

Require Import mathcomp.ssreflect.ssreflect.

Set Implicit Arguments.

Class BaseParamsTotalMap (P0 : BaseParams) (P1 : BaseParams) := 
  {
    tot_map_data : @data P0 -> @data P1 ;
    tot_map_input : @input P0 -> @input P1 ;
    tot_map_output : @output P0 -> @output P1
  }.

Class MultiParamsTotalMap
 (B0 : BaseParams) (B1 : BaseParams) 
 (B : BaseParamsTotalMap B0 B1)
 (P0 : MultiParams B0) (P1 : MultiParams B1)  :=
{
   tot_map_msg : @msg B0 P0 -> @msg B1 P1 ;
   tot_map_name : @name B0 P0 -> @name B1 P1 ;
   tot_map_name_inv : @name B1 P1 -> @name B0 P0
}.

Section TotalMapSimulations.

Context {base_fst : BaseParams}.
Context {base_snd : BaseParams}.
Context {multi_fst : MultiParams base_fst}.
Context {multi_snd : MultiParams base_snd}.
Context {base_map : BaseParamsTotalMap base_fst base_snd}.
Context {multi_map : MultiParamsTotalMap base_map multi_fst multi_snd}.

Hypothesis tot_map_name_inv_inverse : forall n, tot_map_name_inv (tot_map_name n) = n.

Hypothesis tot_map_name_inverse_inv : forall n, tot_map_name (tot_map_name_inv n) = n.

Hypothesis tot_init_handlers_eq : forall n, tot_map_data (init_handlers n) = init_handlers (tot_map_name n).

Definition tot_map_name_msgs :=
  map (fun nm => (tot_map_name (fst nm), tot_map_msg (snd nm))).

Definition tot_mapped_net_handlers me src m st :=
  let '(out, st', ps) := net_handlers me src m st in
  (map tot_map_output out, tot_map_data st', tot_map_name_msgs ps).

Hypothesis tot_net_handlers_eq : forall me src m st,
  tot_mapped_net_handlers me src m st = 
  net_handlers (tot_map_name me) (tot_map_name src) (tot_map_msg m) (tot_map_data st).

Definition tot_mapped_input_handlers me inp st :=
  let '(out, st', ps) := input_handlers me inp st in
  (map tot_map_output out, tot_map_data st', tot_map_name_msgs ps).

Hypothesis tot_input_handlers_eq : forall me inp st,
  tot_mapped_input_handlers me inp st = input_handlers (tot_map_name me) (tot_map_input inp) (tot_map_data st).

Hypothesis tot_map_output_injective : 
  forall o o', tot_map_output o = tot_map_output o' -> o = o'.

Lemma tot_map_name_injective : 
forall n n', tot_map_name n = tot_map_name n' -> n = n'.
Proof.
move => n n'.
case (name_eq_dec n n') => H_dec //.
move => H_eq.
rewrite -(tot_map_name_inv_inverse n) in H_dec.
rewrite H_eq in H_dec.
by rewrite tot_map_name_inv_inverse in H_dec.
Qed.

Definition tot_map_trace_occ (e : @name _ multi_fst * (@input base_fst + list (@output base_fst))) :=
match e with
| (n, inl io) => (tot_map_name n, inl (tot_map_input io))
| (n, inr lo) => (tot_map_name n, inr (map tot_map_output lo))
end.

Definition tot_map_packet (p : @packet base_fst multi_fst)  :=
match p with
| mkPacket src dst m =>
  mkPacket (tot_map_name src) (tot_map_name dst) (tot_map_msg m)
end.

Definition tot_map_net (net : @network _ multi_fst) : @network _ multi_snd :=
mkNetwork (map tot_map_packet net.(nwPackets)) (fun n => tot_map_data (net.(nwState) (tot_map_name_inv n))).

Lemma tot_map_update_eq :
  forall f d h,
    (fun n : name => tot_map_data (update f h d (tot_map_name_inv n))) =
    update (fun n : name => tot_map_data (f (tot_map_name_inv n))) (tot_map_name h) (tot_map_data d).
Proof.
move => net d h.
apply functional_extensionality => n.
rewrite /update /=.
case (name_eq_dec _ _) => H_dec; case (name_eq_dec _ _) => H_dec' //.
  rewrite -H_dec in H_dec'.
  by rewrite tot_map_name_inverse_inv in H_dec'.
rewrite H_dec' in H_dec.
by rewrite tot_map_name_inv_inverse in H_dec.
Qed.

Corollary tot_map_update_packet_eq :
forall f p d,
  (fun n : name => tot_map_data (update f (pDst p) d (tot_map_name_inv n))) =
  (update (fun n : name => tot_map_data (f (tot_map_name_inv n))) (pDst (tot_map_packet p)) (tot_map_data d)).
Proof.
move => f. 
case => src dst m d.
exact: tot_map_update_eq.
Qed.

Lemma tot_map_packet_app_eq :
  forall l p ms ms',
    map tot_map_packet (map (fun m : name * msg => {| pSrc := pDst p; pDst := fst m; pBody := snd m |}) l ++ ms ++ ms') = 
    map (fun m : name * msg => {| pSrc := pDst (tot_map_packet p); pDst := fst m; pBody := snd m |}) (tot_map_name_msgs l) ++ map tot_map_packet ms ++ map tot_map_packet ms'.
Proof.
move => l; case => src dst m ms ms'.
rewrite 2!map_app.
elim: l => //=.
case => /= n m' l IH.
by rewrite IH.
Qed.

Lemma tot_map_packet_eq :
  forall l l' h,
    map tot_map_packet (map (fun m : name * msg => {| pSrc := h; pDst := fst m; pBody := snd m |}) l ++ l') =
    map (fun m : name * msg => {| pSrc := tot_map_name h; pDst := fst m; pBody := snd m |}) (tot_map_name_msgs l) ++ map tot_map_packet l'.
Proof.
elim => //=.
case => n m l IH l' h.
by rewrite IH.
Qed.

Lemma tot_init_handlers_fun_eq : 
    init_handlers = fun n : name => tot_map_data (init_handlers (tot_map_name_inv n)).
Proof.
apply functional_extensionality => n.
rewrite tot_init_handlers_eq.
by rewrite tot_map_name_inverse_inv.
Qed.

Lemma tot_map_trace_occ_inv : 
  forall tr n ol,
    map tot_map_trace_occ tr = [(n, inr ol)] -> 
    exists n', exists lo, tr = [(n', inr lo)] /\ tot_map_name n' = n /\ map tot_map_output lo = ol.
Proof.
case => //=.
case.
move => n ol tr n' lo H_eq.
case: tr H_eq => //=.
case: ol => //=.
move => out H_eq.
exists n; exists out.
split => //.
by inversion H_eq.
Qed.

Lemma tot_map_trace_occ_in_inv : 
  forall tr h inp out,
    map tot_map_trace_occ tr = [(h, inl inp); (h, inr out)] -> 
    exists h', exists inp', exists out', tr = [(h', inl inp'); (h', inr out')] /\ 
      tot_map_name h' = h /\ map tot_map_output out' = out /\ tot_map_input inp' = inp.
Proof.
case => //=.
case.
move => h.
case => //.
move => inp.
case => //.
case.
move => h'.
case => //.
move => out.
case => //=.
move => h0.
move => inp' out' H_eq.
inversion H_eq; subst.
apply tot_map_name_injective in H2.
rewrite H2.
by exists h; exists inp; exists out.
Qed.

Theorem step_m_tot_mapped_simulation_1 :
  forall net net' tr,
    @step_m _ multi_fst net net' tr ->
    @step_m _ multi_snd (tot_map_net net) (tot_map_net net') (map tot_map_trace_occ tr).
Proof.
move => net net' tr.
case => {net net' tr}.
- move => net net' p ms ms' out d l H_eq H_hnd H_eq'.
  rewrite /tot_map_trace_occ /=.
  have ->: tot_map_name (pDst p) = pDst (tot_map_packet p) by case: p H_eq H_hnd H_eq' => src dst m H_eq H_hnd H_eq'.
  apply (@SM_deliver _ _ _ _ _ (map tot_map_packet ms) (map tot_map_packet ms') (map tot_map_output out) (tot_map_data d) (tot_map_name_msgs l)).
  * by rewrite /tot_map_net /= H_eq /= map_app.
  * rewrite /=.
    case: p H_eq H_hnd H_eq' => /= src dst m H_eq H_hnd H_eq'.
    have H_q := tot_net_handlers_eq dst src m (nwState net dst).
    rewrite /tot_mapped_net_handlers in H_q.
    rewrite H_hnd in H_q.
    rewrite H_q.
    by rewrite tot_map_name_inv_inverse.
  * rewrite /= H_eq' /= /tot_map_net /=.
    rewrite -tot_map_update_packet_eq.
    by rewrite tot_map_packet_app_eq.
- move => h net net' out inp d l H_hnd H_eq.
  apply (@SM_input _ _ _ _ _ _ _ (tot_map_data d) (tot_map_name_msgs l)).
    rewrite /=.
    have H_q := tot_input_handlers_eq h inp (nwState net h).
    rewrite /tot_mapped_input_handlers /= in H_q.
    rewrite H_hnd in H_q.
    rewrite H_q.
    by rewrite tot_map_name_inv_inverse.
  rewrite /= H_eq /= /tot_map_net /=.
  rewrite -tot_map_update_eq.
  by rewrite tot_map_packet_eq.
Qed.

Corollary step_m_tot_mapped_simulation_star_1 :
  forall net tr,
    @step_m_star _ multi_fst step_m_init net tr ->
    @step_m_star _ multi_snd step_m_init (tot_map_net net) (map tot_map_trace_occ tr).
Proof.
move => net tr H_step.
remember step_m_init as y in *.
move: Heqy.
induction H_step using refl_trans_1n_trace_n1_ind => H_init /=.
  rewrite H_init.
  rewrite /step_m_init /= /tot_map_net /=.
  rewrite tot_init_handlers_fun_eq.
  exact: RT1nTBase.
concludes.
rewrite H_init in H_step2 H_step1.
apply step_m_tot_mapped_simulation_1 in H.
rewrite map_app.
have H_trans := refl_trans_1n_trace_trans IHH_step1.
apply: H_trans.
rewrite (app_nil_end (map _ _)).
apply: (@RT1nTStep _ _ _ _ (tot_map_net x'')) => //.
exact: RT1nTBase.
Qed.

Theorem step_m_tot_mapped_simulation_2 :
  forall net net' out mnet mout,
      @step_m _ multi_snd net net' out ->
      tot_map_net mnet = net ->
      map tot_map_trace_occ mout = out ->
      exists mnet',
        @step_m _ multi_fst mnet mnet' mout /\
        tot_map_net mnet' = net'.
Proof.
move => net net' out mnet mout H_step H_eq H_eq'.
invcs H_step.
- case: p H4 H H0 => /= src dst m H4 H H0.
  rewrite /tot_map_net /=.
  case: mnet H H0 => /= pks sts H_eq H_hnd.
  have [pks1 [pks2 [H_eq_pks [H_eq_pks1 H_eq_pks2]]]] := map_eq_inv _ _ _ _ H_eq.
  case: pks2 H_eq_pks H_eq_pks2 => //= p pks2 H_eq_pks H_eq_pks2.
  rewrite H_eq_pks.
  inversion H_eq_pks2.
  case H_hnd': (net_handlers (pDst p) (pSrc p) (pBody p) (sts (pDst p))) => [dout l'].
  case: dout H_hnd' => out' d' H_hnd'.
  rewrite -H_eq_pks1.
  exists {| nwPackets := send_packets (pDst p) l' ++ pks1 ++ pks2 ; nwState := update sts (pDst p) d' |}.
  split.
  * have [n' [lo [H_eq_mout [H_eq_n H_eq_lo]]]] := tot_map_trace_occ_inv _ (eq_sym H4).
    rewrite H_eq_mout.
    have H_eq_dst: n' = pDst p.
      rewrite -(tot_map_name_inv_inverse n').
      rewrite H_eq_n.
      case: p H_eq_pks H_eq_pks2 H0 H_hnd' => src' dst' m' H_eq_pks H_eq_pks2 H0 H_hnd'.
      rewrite /=.
      rewrite /= in H0.
      inversion H0.
      by rewrite tot_map_name_inv_inverse.
    rewrite H_eq_dst.
    apply (@SM_deliver _ _ _ _ _ pks1 pks2 _ d' l') => //=.
    suff H_suff: lo = out' by rewrite H_suff.
    have H_eq_hnd := tot_net_handlers_eq (pDst p) (pSrc p) (pBody p) (sts (pDst p)).
    rewrite /tot_mapped_net_handlers /= in H_eq_hnd.
    repeat break_let.
    inversion H_hnd'.
    rewrite H2 H3 H5 in H_eq_hnd.
    rewrite -{1}H_eq_dst H_eq_n in H_eq_hnd.
    rewrite -H_eq_dst in H_eq_hnd.
    rewrite -(tot_map_name_inv_inverse n') H_eq_n in H_eq_hnd.
    move {Heqp1 Heqp0 H_hnd'}.
    have H_eq_src: tot_map_name (pSrc p) = src.
      case: p H_eq_pks H_eq_pks2 H0 H_eq_dst H_eq_hnd => src' dst' m' H_eq_pks H_eq_pks2 H0 H_eq_dst H_eq_hnd.
      rewrite /=.
      rewrite /= in H0.
      by inversion H0.
    rewrite H_eq_src /= {H_eq_src} in H_eq_hnd.
    have H_eq_body: tot_map_msg (pBody p) = m.
      case: p H_eq_pks H_eq_pks2 H0 H_eq_dst H_eq_hnd => src' dst' m' H_eq_pks H_eq_pks2 H0 H_eq_dst H_eq_hnd.
      rewrite /=.
      rewrite /= in H0.
      by inversion H0.
    rewrite H_eq_body H_hnd in H_eq_hnd.
    inversion H_eq_hnd.
    rewrite -H_eq_lo in H6.
    symmetry.
    move: H6.
    apply map_eq_inv_eq.
    exact: tot_map_output_injective.
  * rewrite /=.
    rewrite /update /=.
    have H_eq_dst: tot_map_name (pDst p) = dst.
      case: p H_eq_pks H_eq_pks2 H0 H_hnd' => src' dst' m' H_eq_pks H_eq_pks2 H0 H_hnd'.
      by inversion H0.
    have H_eq_src: tot_map_name (pSrc p) = src.
      case: p H_eq_pks H_eq_pks2 H0 H_hnd' H_eq_dst => src' dst' m' H_eq_pks H_eq_pks2 H0 H_hnd' H_eq_dst.
      by inversion H0.
    have H_eq_body: tot_map_msg (pBody p) = m.
      case: p H_eq_pks H_eq_pks2 H0 H_eq_dst H_eq_src H_hnd' => src' dst' m' H_eq_pks H_eq_pks2 H0 H_eq_dst H_eq_src H_hnd'.
      by inversion H0.
    rewrite 2!map_app.
    have H_eq_hnd := tot_net_handlers_eq (pDst p) (pSrc p) (pBody p) (sts (pDst p)).
    rewrite /tot_mapped_net_handlers /= in H_eq_hnd.
    repeat break_let.
    inversion H_hnd'.
    rewrite H_eq_dst H_eq_src H_eq_body in H_eq_hnd.
    rewrite -{2}H_eq_dst tot_map_name_inv_inverse in H_hnd.
    rewrite H_hnd in H_eq_hnd.
    inversion H_eq_hnd.
    rewrite H2 in H6.
    rewrite H3 in H7.
    rewrite H5 in H8.
    rewrite H3 H5.
    set nwP1 := map tot_map_packet _.
    set nwP2 := map (fun _ => _) (tot_map_name_msgs _).
    set nwS1 := fun _ => _.
    set nwS2 := fun _ => _.
    have H_eq_nw: nwP1 = nwP2.
      rewrite /nwP1 /nwP2 {H_hnd' H5 H8 nwP1 nwP2}.
      elim: l' => //=.
      case => /= n' m' l' IH.
      rewrite IH.
      by rewrite H_eq_dst.
    rewrite -H_eq_nw /nwP1 {H_eq_nw nwP1 nwP2}.
    have H_eq_sw: nwS1 = nwS2.
      rewrite /nwS1 /nwS2.
      apply functional_extensionality => n'.
      rewrite -H_eq_dst.
      case (name_eq_dec _ _) => H_dec.
        rewrite -H_dec.
        rewrite tot_map_name_inverse_inv.
        by case (name_eq_dec _ _).
      case (name_eq_dec _ _) => H_dec' //.
      rewrite H_dec' in H_dec.
      by rewrite tot_map_name_inv_inverse in H_dec.
    by rewrite H_eq_sw.
- rewrite /tot_map_net /=.
  case: mnet H => /= pks sts H_hnd.
  have [h' [inp' [out' [H_eq_mout [H_eq_n [H_eq_out H_eq_inp]]]]]] := tot_map_trace_occ_in_inv _ (eq_sym H3).
  have H_q := tot_input_handlers_eq h' inp' (sts h').
  rewrite /tot_mapped_input_handlers in H_q.
  repeat break_let.
  rewrite H_eq_n H_eq_inp in H_q.
  rewrite -{2}H_eq_n tot_map_name_inv_inverse in H_hnd.
  rewrite H_hnd in H_q.
  inversion H_q.
  rewrite -H_eq_out in H0.
  rewrite H1 H2.
  exists ({| nwPackets := send_packets h' l0 ++ pks ; nwState := update sts h' d0 |}).
  split.
  * rewrite H_eq_mout.
    apply (@SM_input _ _ _ _ _ _ _ d0 l0) => //.
    rewrite /= Heqp.
    suff H_suff: l1 = out' by rewrite H_suff.
    move: H0.
    apply map_eq_inv_eq.
    exact: tot_map_output_injective.
  * rewrite /= map_app.
    set nwP1 := map tot_map_packet _.
    set nwP2 := map (fun _ => _) l.
    set nwS1 := fun _ => _.
    set nwS2 := update _ _ _.
    have H_eq_nwp: nwP1 = nwP2.
      rewrite /nwP1 /nwP2 {Heqp H_q nwP1 nwP2}.
      rewrite -H2 {H2}.
      elim: l0 => //=.
      case => /= n m l0 IH.
      by rewrite H_eq_n IH.
    have H_eq_nws: nwS1 = nwS2.
      rewrite /nwS1 /nwS2.
      rewrite /update /=.
      apply functional_extensionality => n.
      rewrite -H_eq_n -H1.
      case (name_eq_dec _ _) => H_dec.
        case (name_eq_dec _ _) => H_dec' //.
        by rewrite -H_dec tot_map_name_inverse_inv in H_dec'.
      case (name_eq_dec _ _) => H_dec' //.
      by rewrite H_dec' tot_map_name_inv_inverse in H_dec.
    by rewrite H_eq_nwp H_eq_nws.
Qed.

Context {fail_fst : FailureParams multi_fst}.
Context {fail_snd : FailureParams multi_snd}.

Hypothesis tot_reboot_eq : forall d, tot_map_data (reboot d) = reboot (tot_map_data d).

Lemma not_in_failed_not_in :
  forall n failed,
    ~ In n failed ->
    ~ In (tot_map_name n) (map tot_map_name failed).
Proof.
move => n.
elim => //=.
move => n' failed IH H_in H_in'.
case: H_in' => H_in'.
  case: H_in.
  left.
  rewrite -(tot_map_name_inv_inverse n').
  rewrite H_in'.
  exact: tot_map_name_inv_inverse.
contradict H_in'.
apply: IH.
move => H_in'.
case: H_in.
by right.
Qed.

Lemma in_failed_in :
  forall n failed,
    In n failed ->
    In (tot_map_name n) (map tot_map_name failed).
Proof.
move => n.
elim => //.
move => n' l IH H_in.
case: H_in => H_in.
  rewrite H_in.
  by left.
right.
exact: IH.
Qed.

Lemma remove_tot_map_eq :
  forall h failed,
    map tot_map_name (remove name_eq_dec h failed) =
    remove name_eq_dec (tot_map_name h) (map tot_map_name failed).
Proof.
move => h.
elim => //=.
move => n failed IH.
case (name_eq_dec _ _) => H_eq; case (name_eq_dec _ _) => H_eq' //.
- by rewrite H_eq in H_eq'.
- rewrite -(tot_map_name_inv_inverse h) in H_eq.
  rewrite H_eq' in H_eq.
  by rewrite tot_map_name_inv_inverse in H_eq.
- by rewrite /= IH.
Qed.

Lemma tot_map_reboot_eq :
forall h net,
    (fun n : name => 
      tot_map_data 
        (match name_eq_dec (tot_map_name_inv n) h with
         | left _ => reboot (nwState net (tot_map_name_inv n))
         | right _ => nwState net (tot_map_name_inv n)
        end)) =
    (fun nm : name =>
       match name_eq_dec nm (tot_map_name h) with
       | left _ => reboot (tot_map_data (nwState net (tot_map_name_inv nm)))
       | right _ => tot_map_data (nwState net (tot_map_name_inv nm))
       end).
Proof.
move => h net.
apply: functional_extensionality => n.
case (name_eq_dec _ _) => H_dec; case (name_eq_dec _ _) => H_dec' //.
- rewrite -H_dec in H_dec'.
  by rewrite tot_map_name_inverse_inv in H_dec'.
- rewrite H_dec' in H_dec.
  by rewrite tot_map_name_inv_inverse in H_dec.
Qed.

Theorem step_f_tot_mapped_simulation_1 :
  forall net net' failed failed' tr,
    @step_f _ _ fail_fst (failed, net) (failed', net') tr ->
    @step_f _ _ fail_snd (map tot_map_name failed, tot_map_net net) (map tot_map_name failed', tot_map_net net') (map tot_map_trace_occ tr).
Proof.
move => net net' failed failed' tr H_step.
invcs H_step.
- have ->: tot_map_name (pDst p) = pDst (tot_map_packet p) by case: p H3 H4 H6 => src dst m.
  apply (@SF_deliver _ _ _ _ _ _ _ (map tot_map_packet xs) (map tot_map_packet ys) _ (tot_map_data d) (tot_map_name_msgs l)).
  * by rewrite /tot_map_net /= H3 /= map_app.
  * case: p H3 H4 H6 => /= src dst m H3 H4 H6.
    exact: not_in_failed_not_in.
  * case: p H3 H4 H6 => /= src dst m H3 H4 H6.        
    have H_q := tot_net_handlers_eq dst src m (nwState net dst).
    rewrite /tot_mapped_net_handlers in H_q.
    rewrite H6 in H_q.
    rewrite H_q.
    by rewrite tot_map_name_inv_inverse.
  * rewrite /= -tot_map_update_packet_eq /=.
    rewrite /tot_map_net /=.
    by rewrite tot_map_packet_app_eq.
- apply (@SF_input _ _ _ _ _ _ _ _ _ (tot_map_data d) (tot_map_name_msgs l)).
  * exact: not_in_failed_not_in.
  * rewrite /=.
    have H_q := tot_input_handlers_eq h inp (nwState net h).
    rewrite /tot_mapped_input_handlers /= in H_q.
    rewrite H5 in H_q.
    rewrite H_q.
    by rewrite tot_map_name_inv_inverse.
  * rewrite /= /tot_map_net /=.
    rewrite -tot_map_update_eq.
    by rewrite tot_map_packet_eq.
- apply (@SF_drop _ _ _ _ _ _ (tot_map_packet p) (map tot_map_packet xs) (map tot_map_packet ys)).
  * by rewrite /tot_map_net /= H4 map_app.
  * by rewrite /tot_map_net /= map_app.
- apply (@SF_dup _ _ _ _ _ _ (tot_map_packet p) (map tot_map_packet xs) (map tot_map_packet ys)).
  * by rewrite /tot_map_net /= H4 map_app.
  * by rewrite /tot_map_net /= map_app.
- exact: SF_fail.
- apply: (SF_reboot (tot_map_name h)).
  * exact: in_failed_in.
  * by rewrite remove_tot_map_eq.
  * rewrite /tot_map_net /=.
    by rewrite tot_map_reboot_eq.
Qed.

Corollary step_f_tot_mapped_simulation_star_1 :
  forall net failed tr,
    @step_f_star _ _ fail_fst step_f_init (failed, net) tr ->
    @step_f_star _ _ fail_snd step_f_init (map tot_map_name failed, tot_map_net net) (map tot_map_trace_occ tr).
Proof.
move => net failed tr H_step.
remember step_f_init as y in *.
have H_eq_f: failed = fst (failed, net) by [].
have H_eq_n: net = snd (failed, net) by [].
rewrite H_eq_f {H_eq_f}.
rewrite {2}H_eq_n {H_eq_n}.
move: Heqy.
induction H_step using refl_trans_1n_trace_n1_ind => H_init /=.
  rewrite H_init.
  rewrite /step_f_init /= /step_m_init /tot_map_net /=.
  rewrite tot_init_handlers_fun_eq.
  exact: RT1nTBase.
concludes.
rewrite H_init {H_init x} in H_step2 H_step1.
case: x' H IHH_step1 H_step1 => failed' net'.
case: x'' H_step2 => failed'' net''.
rewrite /=.
move => H_step2 H IHH_step1 H_step1.
apply step_f_tot_mapped_simulation_1 in H.
rewrite map_app.
have H_trans := refl_trans_1n_trace_trans IHH_step1.
apply: H_trans.
rewrite (app_nil_end (map tot_map_trace_occ _)).
apply (@RT1nTStep _ _ _ _ (map tot_map_name failed'', tot_map_net net'')) => //.
exact: RT1nTBase.
Qed.

Lemma map_eq_name_eq_eq :
  forall l l', map tot_map_name l = map tot_map_name l' -> l = l'.
Proof.
elim.
case => //=.
move => n l IH.
case => //=.
move => n' l' H_eq.
inversion H_eq.
apply tot_map_name_injective in H0.
by rewrite H0 (IH l').
Qed.

Theorem step_f_tot_mapped_simulation_2 :
  forall net net' failed failed' out mnet mfailed mfailed' mout,
      @step_f _ _ fail_snd (failed, net) (failed', net') out ->
      tot_map_net mnet = net ->
      map tot_map_name mfailed = failed ->
      map tot_map_name mfailed' = failed' ->
      map tot_map_trace_occ mout = out ->
      exists mnet',
        @step_f _ _ fail_fst (mfailed, mnet) (mfailed', mnet') mout /\
        tot_map_net mnet' = net'.
Proof.
move => net net' failed failed' out mnet mfailed mfailed' mout H_step H_eq_net H_eq_f H_eq_f' H_eq_out.
invcs H_step.
- case: p H4 H5 H3 H6 => /= src dst m H4 H5 H3 H6.
  rewrite /tot_map_net /=.
  case: mnet H3 H6 => /= pks sts H_eq H_hnd.
  have [pks1 [pks2 [H_eq_pks [H_eq_pks1 H_eq_pks2]]]] := map_eq_inv _ _ _ _ H_eq.
  case: pks2 H_eq_pks H_eq_pks2 => //= p pks2 H_eq_pks H_eq_pks2.
  rewrite H_eq_pks.
  inversion H_eq_pks2.
  case H_hnd': (net_handlers (pDst p) (pSrc p) (pBody p) (sts (pDst p))) => [dout l'].
  case: dout H_hnd' => out' d' H_hnd'.
  rewrite -H_eq_pks1.
  exists {| nwPackets := send_packets (pDst p) l' ++ pks1 ++ pks2 ; nwState := update sts (pDst p) d' |}.
  split.
  * have [n' [lo [H_eq_mout [H_eq_n H_eq_lo]]]] := tot_map_trace_occ_inv _ (eq_sym H5).
    rewrite H_eq_mout.
    have H_eq_dst: n' = pDst p.
      rewrite -(tot_map_name_inv_inverse n').
      rewrite H_eq_n.
      case: p H_eq_pks H_eq_pks2 H0 H_hnd' => src' dst' m' H_eq_pks H_eq_pks2 H0 H_hnd'.
      rewrite /=.
      rewrite /= in H0.
      inversion H0.
      by rewrite tot_map_name_inv_inverse.
    rewrite H_eq_dst.
    apply map_eq_name_eq_eq in H1.
    rewrite H1.    
    apply (@SF_deliver _ _ _ _ _ _ _ pks1 pks2 _ d' l') => //=.
      rewrite -H_eq_dst.
      rewrite -H_eq_n in H4.
      move => H_in.
      by apply in_failed_in in H_in.
    suff H_suff: lo = out' by rewrite H_suff.
    have H_eq_hnd := tot_net_handlers_eq (pDst p) (pSrc p) (pBody p) (sts (pDst p)).
    rewrite /tot_mapped_net_handlers /= in H_eq_hnd.
    repeat break_let.
    inversion H_hnd'.
    rewrite H3 H6 H7 in H_eq_hnd.
    rewrite -{1}H_eq_dst H_eq_n in H_eq_hnd.
    rewrite -H_eq_dst in H_eq_hnd.
    rewrite -(tot_map_name_inv_inverse n') H_eq_n in H_eq_hnd.
    move {Heqp1 Heqp0 H_hnd'}.
    have H_eq_src: tot_map_name (pSrc p) = src.
      case: p H_eq_pks H_eq_pks2 H0 H_eq_dst H_eq_hnd => src' dst' m' H_eq_pks H_eq_pks2 H0 H_eq_dst H_eq_hnd.
      rewrite /=.
      rewrite /= in H0.
      by inversion H0.
    rewrite H_eq_src /= {H_eq_src} in H_eq_hnd.
    have H_eq_body: tot_map_msg (pBody p) = m.
      case: p H_eq_pks H_eq_pks2 H0 H_eq_dst H_eq_hnd => src' dst' m' H_eq_pks H_eq_pks2 H0 H_eq_dst H_eq_hnd.
      rewrite /=.
      rewrite /= in H0.
      by inversion H0.
    rewrite H_eq_body H_hnd in H_eq_hnd.
    inversion H_eq_hnd.
    rewrite -H_eq_lo in H8.
    symmetry.
    move: H8.
    apply map_eq_inv_eq.
    exact: tot_map_output_injective.
  * rewrite /=.
    rewrite /update /=.
    have H_eq_dst: tot_map_name (pDst p) = dst.
      case: p H_eq_pks H_eq_pks2 H0 H_hnd' => src' dst' m' H_eq_pks H_eq_pks2 H0 H_hnd'.
      by inversion H0.
    have H_eq_src: tot_map_name (pSrc p) = src.
      case: p H_eq_pks H_eq_pks2 H0 H_hnd' H_eq_dst => src' dst' m' H_eq_pks H_eq_pks2 H0 H_hnd' H_eq_dst.
      by inversion H0.
    have H_eq_body: tot_map_msg (pBody p) = m.
      case: p H_eq_pks H_eq_pks2 H0 H_eq_dst H_eq_src H_hnd' => src' dst' m' H_eq_pks H_eq_pks2 H0 H_eq_dst H_eq_src H_hnd'.
      by inversion H0.
    rewrite 2!map_app.
    have H_eq_hnd := tot_net_handlers_eq (pDst p) (pSrc p) (pBody p) (sts (pDst p)).
    rewrite /tot_mapped_net_handlers /= in H_eq_hnd.
    repeat break_let.
    inversion H_hnd'.
    rewrite H_eq_dst H_eq_src H_eq_body in H_eq_hnd.
    rewrite -{2}H_eq_dst tot_map_name_inv_inverse in H_hnd.
    rewrite H_hnd in H_eq_hnd.
    inversion H_eq_hnd.
    rewrite H3 in H8.
    rewrite H6 in H9.
    rewrite H7 in H10.
    rewrite H6 H7.
    set nwP1 := map tot_map_packet _.
    set nwP2 := map (fun _ => _) (tot_map_name_msgs _).
    set nwS1 := fun _ => _.
    set nwS2 := fun _ => _.
    have H_eq_nw: nwP1 = nwP2.
      rewrite /nwP1 /nwP2 {H_hnd' H7 H10 nwP1 nwP2}.
      elim: l' => //=.
      case => /= n' m' l' IH.
      rewrite IH.
      by rewrite H_eq_dst.
    rewrite -H_eq_nw /nwP1 {H_eq_nw nwP1 nwP2}.
    have H_eq_sw: nwS1 = nwS2.
      rewrite /nwS1 /nwS2.
      apply functional_extensionality => n'.
      rewrite -H_eq_dst.
      case (name_eq_dec _ _) => H_dec.
        rewrite -H_dec.
        rewrite tot_map_name_inverse_inv.
        by case (name_eq_dec _ _).
      case (name_eq_dec _ _) => H_dec' //.
      rewrite H_dec' in H_dec.
      by rewrite tot_map_name_inv_inverse in H_dec.
    by rewrite H_eq_sw.
- rewrite /tot_map_net /=.
  case: mnet H5 => /= pks sts H_hnd.
  have [h' [inp' [out' [H_eq_mout [H_eq_n [H_eq_out H_eq_inp]]]]]] := tot_map_trace_occ_in_inv _ (eq_sym H4).
  have H_q := tot_input_handlers_eq h' inp' (sts h').
  rewrite /tot_mapped_input_handlers in H_q.
  repeat break_let.
  rewrite H_eq_n H_eq_inp in H_q.
  rewrite -{2}H_eq_n tot_map_name_inv_inverse in H_hnd.
  rewrite H_hnd in H_q.
  inversion H_q.
  rewrite -H_eq_out in H0.
  rewrite H2 H5.
  apply map_eq_name_eq_eq in H1.
  rewrite -H1.
  rewrite -H1 in H3.
  exists ({| nwPackets := send_packets h' l0 ++ pks ; nwState := update sts h' d0 |}).
  split.
  * rewrite H_eq_mout.
    apply (@SF_input _ _ _ _ _ _ _ _ _ d0 l0) => //.      
      rewrite -H_eq_n in H3.
      move => H_in.
      by apply in_failed_in in H_in.
    rewrite /= Heqp.
    suff H_suff: l1 = out' by rewrite H_suff.
    move: H0.
    apply map_eq_inv_eq.
    exact: tot_map_output_injective.
  * rewrite /= map_app.
    set nwP1 := map tot_map_packet _.
    set nwP2 := map (fun _ => _) l.
    set nwS1 := fun _ => _.
    set nwS2 := update _ _ _.
    have H_eq_nwp: nwP1 = nwP2.
      rewrite /nwP1 /nwP2 {Heqp H_q nwP1 nwP2}.
      rewrite -H5 {H5}.
      elim: l0 => //=.
      case => /= n m l0 IH.
      by rewrite H_eq_n IH.
    have H_eq_nws: nwS1 = nwS2.
      rewrite /nwS1 /nwS2.
      rewrite /update /=.
      apply functional_extensionality => n.
      rewrite -H_eq_n -H2.
      case (name_eq_dec _ _) => H_dec.
        case (name_eq_dec _ _) => H_dec' //.
        by rewrite -H_dec tot_map_name_inverse_inv in H_dec'.
      case (name_eq_dec _ _) => H_dec' //.
      by rewrite H_dec' tot_map_name_inv_inverse in H_dec.
    by rewrite H_eq_nwp H_eq_nws.
- case: mout H2 => // H_eq_mout {H_eq_mout}.
  apply map_eq_name_eq_eq in H1.
  rewrite -H1.
  have [pks1 [pks2 [H_eq_pks [H_eq_pks1 H_eq_pks2]]]] := map_eq_inv _ _ _ _ H4.
  case: pks2 H_eq_pks H_eq_pks2 => //= p' pks2 H_eq_pks H_eq_pks2.
  inversion H_eq_pks2.
  rewrite -H_eq_pks1.
  exists {| nwPackets := pks1 ++ pks2 ; nwState := nwState mnet |}.
  split; first exact: (@SF_drop _ _ _ _ _ _ p' pks1 pks2).
  by rewrite /tot_map_net /= map_app.
- case: mout H2 => // H_eq_mout {H_eq_mout}.
  apply map_eq_name_eq_eq in H1.
  rewrite -H1.
  have [pks1 [pks2 [H_eq_pks [H_eq_pks1 H_eq_pks2]]]] := map_eq_inv _ _ _ _ H4.
  case: pks2 H_eq_pks H_eq_pks2 => //= p' pks2 H_eq_pks H_eq_pks2.
  inversion H_eq_pks2.
  rewrite -H_eq_pks1.
  exists {| nwPackets := p' :: pks1 ++ p' :: pks2 ; nwState := nwState mnet |}.
  split; first exact: (@SF_dup _ _ _ _ _ _ p' pks1 pks2).
  by rewrite /tot_map_net /= map_app.
- case: mout H2 => // H_eq_mout {H_eq_mout}.
  case: mfailed' H => //= h' mfailed' H_eq.
  inversion H_eq.
  apply map_eq_name_eq_eq in H1.
  rewrite -H1.
  exists mnet.
  split => //.
  exact: SF_fail.
- case: mout H4 => // H_eq_mout {H_eq_mout}.
  have H_in := H3.
  apply in_split in H_in.
  move: H_in => [ns1 [ns2 H_eq]].
  have [mns1 [mns2 [H_eq_mns [H_eq_mns1 H_eq_mns2]]]] := map_eq_inv _ _ _ _ H_eq.
  case: mns2 H_eq_mns H_eq_mns2 => //= h' mns2 H_eq_mns H_eq_mns2.
  exists {| nwPackets := nwPackets mnet ; 
       nwState := (fun nm => match name_eq_dec nm h' with
                           | left _ => (reboot (nwState mnet nm)) 
                           | right _ => (nwState mnet nm) 
                           end) |}.
  split.
  * apply (@SF_reboot _ _ _ h') => //.
    + rewrite H_eq_mns.
      apply in_or_app.
      by right; left.
    + inversion H_eq_mns2.
      rewrite -H0 in H5.
      move {H3 ns1 ns2 H_eq mns1 H_eq_mns1 h mns2 H_eq_mns H_eq_mns2 H0 H1}.
      have H_eq: remove name_eq_dec (tot_map_name h') (map tot_map_name mfailed) = map tot_map_name (remove name_eq_dec h' mfailed).
        move {H5 mfailed'}.
        elim: mfailed => //=.
        move => n l IH.
        case (name_eq_dec _ _) => H_dec; case (name_eq_dec _ _) => H_dec' => //.
        + by apply tot_map_name_injective in H_dec.
        + by rewrite H_dec' in H_dec.
        + by rewrite /= IH.               
      rewrite H_eq in H5.
      by apply map_eq_name_eq_eq in H5.
  * rewrite /tot_map_net /=.
    inversion H_eq_mns2.
    set nwS1 := fun _ => _.
    set nwS2 := fun _ => _.
    have H_eq_sw: nwS1 = nwS2.
      rewrite /nwS1 /nwS2 {nwS1 nwS2}.
      apply functional_extensionality => n.
      case (name_eq_dec _ _) => H_dec; case (name_eq_dec _ _) => H_dec' => //.
      + rewrite -H_dec in H_dec'.
        by rewrite tot_map_name_inverse_inv in H_dec'.
      + rewrite H_dec' in H_dec.
        by rewrite tot_map_name_inv_inverse in H_dec.
    by rewrite H_eq_sw.
Qed.

Lemma collate_neq :
  forall h n n' ns f,
    h <> n ->
    collate h f ns n n' = f n n'.
Proof.
move => h n n' ns f H_neq.
move: f.
elim: ns => //.
case.
move => n0 mg ms IH f.
rewrite /=.
rewrite IH.
rewrite /update2 /=.
case (sumbool_and _ _) => H_and //.
by move: H_and => [H_and H_and'].
Qed.

Lemma collate_not_in_eq :
  forall h' h f l,
 ~ In h (map (fun nm : name * msg => fst nm) l) -> 
  collate h' f l h' h = f h' h.
Proof.
move => h' h f l.
elim: l f => //=.
case => n m l IH f H_in.
rewrite IH /update2.
  case (sumbool_and _ _ _ _) => H_dec //.
  by case: H_in; left; move: H_dec => [H_eq H_eq'].
move => H_in'.
case: H_in.
by right.
Qed.

Lemma collate_app :
  forall h' l1 l2 f,
  collate h' f (l1 ++ l2) = collate h' (collate h' f l1) l2.
Proof.
move => h'.
elim => //.
case => n m l1 IH l2 f.
rewrite /=.
by rewrite IH.
Qed.

Lemma collate_f_eq :
  forall  f g h h' l,
  f h h' = g h h' ->
  collate h f l h h' = collate h g l h h'.
Proof.
move => f g h h' l.
elim: l f g => //.
case => n m l IH f g H_eq.
rewrite /=.
set f' := update2 _ _ _ _.
set g' := update2 _ _ _ _.
rewrite (IH f' g') //.
rewrite /f' /g' {f' g'}.
rewrite /update2 /=.
case (sumbool_and _ _ _ _) => H_dec //.
move: H_dec => [H_eq_h H_eq_n].
by rewrite H_eq_n H_eq.
Qed.

Lemma collate_neq_update2 :
  forall h h' n f l ms,
  n <> h' ->
  collate h (update2 f h n ms) l h h' = collate h f l h h'.
Proof.
move => h h' n f l ms H_neq.
have H_eq: update2 f h n ms h h' =  f h h'.
  rewrite /update2 /=.
  by case (sumbool_and _ _ _ _) => H_eq; first by move: H_eq => [H_eq H_eq'].
by rewrite (collate_f_eq _ _ _ _ _ H_eq).
Qed.

Lemma collate_not_in :
  forall h h' l1 l2 f,
  ~ In h' (map (fun nm : name * msg => fst nm) l1) ->
  collate h f (l1 ++ l2) h h' = collate h f l2 h h'.
Proof.
move => h h' l1 l2 f H_in.
rewrite collate_app.
elim: l1 f H_in => //.
case => n m l IH f H_in.
rewrite /= IH.
  have H_neq: n <> h' by move => H_eq; case: H_in; left.
  by rewrite collate_neq_update2.
move => H_in'.
case: H_in.
by right.
Qed.

Lemma collate_not_in_mid :
 forall h h' l1 l2 f m,
   ~ In h (map (fun nm : name * msg => fst nm) (l1 ++ l2)) ->
   collate h' (update2 f h' h (f h' h ++ [m])) (l1 ++ l2) = collate h' f (l1 ++ (h, m) :: l2).
Proof.
move => h h' l1 l2 f m H_in.
apply functional_extensionality => from.
apply functional_extensionality => to.
case (name_eq_dec h' from) => H_dec.
  rewrite -H_dec.
  case (name_eq_dec h to) => H_dec'.
    rewrite -H_dec'.
    rewrite collate_not_in; last first.
      move => H_in'.
      case: H_in.
      rewrite map_app.
      apply in_or_app.
      by left.
    rewrite collate_not_in //.
    move => H_in'.
    case: H_in.
    rewrite map_app.
    apply in_or_app.
    by left.
  rewrite collate_neq_update2 //.
  rewrite 2!collate_app.
  rewrite /=.
  by rewrite collate_neq_update2.
rewrite collate_neq //.
rewrite collate_neq //.
rewrite /update2 /=.
case (sumbool_and _ _) => H_dec' //.
by move: H_dec' => [H_eq H_eq'].
Qed.

Lemma permutation_map_fst :
  forall l l',
  Permutation l l' ->
  Permutation (map (fun nm : name * msg => fst nm) l) (map (fun nm : name * msg => fst nm) l').
Proof.
elim.
  move => l' H_pm.
  apply Permutation_nil in H_pm.
  by rewrite H_pm.
case => /= n m l IH l' H_pm.
have H_in: In (n, m) ((n, m) :: l) by left.
have H_in': In (n, m) l'.
  move: H_pm H_in.
  exact: Permutation_in.
apply in_split in H_in'.
move: H_in' => [l1 [l2 H_eq]].
rewrite H_eq in H_pm.
apply Permutation_cons_app_inv in H_pm.
rewrite H_eq.
apply IH in H_pm.
move: H_pm.
rewrite 2!map_app /=.
move => H_pm.
exact: Permutation_cons_app.
Qed.

Lemma nodup_perm_collate_eq :
  forall h f l l',
    NoDup (map (fun nm => fst nm) l) ->
    Permutation l l' ->
    collate h f l = collate h f l'.
Proof.
move => h f l.
elim: l h f.
  move => h f l' H_nd H_pm.
  apply Permutation_nil in H_pm.
  by rewrite H_pm.
case => h m l IH h' f l' H_nd.
rewrite /= in H_nd.
inversion H_nd; subst.
move => H_pm.
rewrite /=.
have H_in': In (h, m) ((h, m) :: l) by left.
have H_pm' := Permutation_in _ H_pm H_in'.
apply in_split in H_pm'.
move: H_pm' => [l1 [l2 H_eq]].
rewrite H_eq.
rewrite H_eq in H_pm.
apply Permutation_cons_app_inv in H_pm.
have IH' := IH h' (update2 f h' h (f h' h ++ [m])) _ H2 H_pm.
rewrite IH'.
rewrite collate_not_in_mid //.
move => H_in.
case: H1.
suff H_pm': Permutation (map (fun nm : name * msg => fst nm) l) (map (fun nm : name * msg => fst nm) (l1 ++ l2)).
  move: H_in.
  apply Permutation_in.
  exact: Permutation_sym.
exact: permutation_map_fst.
Qed.

Lemma nodup_to_map_name :
  forall ns, NoDup ns ->
        NoDup (map tot_map_name ns).
Proof.
elim => /=; first by move => H_nd; exact: NoDup_nil.
move => n ns IH H_nd.
inversion H_nd.
apply IH in H2.
by apply NoDup_cons; first exact: not_in_failed_not_in.  
Qed.

Lemma permutation_nodes :
  Permutation nodes (map tot_map_name nodes).
Proof.
apply: NoDup_Permutation; last split.
- exact: no_dup_nodes.
- apply nodup_to_map_name.
  exact: no_dup_nodes.
- move => H_in.
  set x' := tot_map_name_inv x.
  have H_in' := all_names_nodes x'. 
  apply in_split in H_in'.
  move: H_in' => [ns1 [ns2 H_eq]].
  rewrite H_eq map_app /= /x'.
  apply in_or_app.
  right; left.
  by rewrite tot_map_name_inverse_inv.
- move => H_in.
  exact: all_names_nodes.
Qed.

Lemma not_in_exclude :
  forall (n : @name base_fst multi_fst) ns failed,
    ~ In n ns ->
    ~ In n (exclude failed ns).
Proof.
move => n.
elim => //.
move => n' l IH failed H_in.
rewrite /=.
case (in_dec _ _) => H_dec.
  apply IH.
  move => H_in'.
  case: H_in.
  by right.
move => H_in'.
case: H_in' => H_in'.
  case: H_in.
  by left.
contradict H_in'.
apply: IH.
move => H_in'.
case: H_in.
by right.
Qed.

Lemma not_in_exclude_snd :
  forall n ns failed,
    ~ In n ns ->
    ~ In n (exclude failed ns).
Proof.
move => n.
elim => //.
move => n' l IH failed H_in.
rewrite /=.
case (in_dec _ _) => H_dec.
  apply IH.
  move => H_in'.
  case: H_in.
  by right.
move => H_in'.
case: H_in' => H_in'.
  case: H_in.
  by left.
contradict H_in'.
apply: IH.
move => H_in'.
case: H_in.
by right.
Qed.

Lemma nodup_exclude :
  forall (ns : list (@name base_fst multi_fst)) failed, NoDup ns ->
               NoDup (exclude failed ns).
Proof.
elim => //.
move => n ns IH failed H_nd.
rewrite /=.
inversion H_nd.
case (in_dec _ _ _) => H_dec; first exact: IH.
apply NoDup_cons; last exact: IH.
exact: not_in_exclude.
Qed.

Lemma nodup_exclude_snd :
  forall ns failed, NoDup ns ->
               NoDup (exclude failed ns).
Proof.
elim => //.
move => n ns IH failed H_nd.
rewrite /=.
inversion H_nd.
case (in_dec _ _ _) => H_dec; first exact: IH.
apply NoDup_cons; last exact: IH.
exact: not_in_exclude_snd.
Qed.

Context {overlay_fst : OverlayParams multi_fst}.
Context {overlay_snd : OverlayParams multi_snd}.

Lemma not_in_msg_for :
  forall (n : @name base_fst multi_fst) h m ns,
    ~ In n ns ->
    ~ In (n, m) (msg_for m (adjacent_to_node h ns)).
Proof.
move => n h m.
elim => //=.
move => n' ns IH H_in.
case (adjacent_to_dec _ _) => H_dec.
  rewrite /=.
  move => H_in'.
  case: H_in' => H_in'.
    inversion H_in'.
    by case: H_in; left.
  contradict H_in'.
  apply: IH.
  move => H_in'.
  case: H_in.
  by right.
apply: IH.
move => H_in'.
case: H_in.
by right.
Qed.

Lemma not_in_msg_for_snd :
  forall n h m ns,
    ~ In n ns ->
    ~ In (n, m) (msg_for m (adjacent_to_node h ns)).
Proof.
move => n h m.
elim => //=.
move => n' ns IH H_in.
case (adjacent_to_dec _ _) => H_dec.
  rewrite /=.
  move => H_in'.
  case: H_in' => H_in'.
    inversion H_in'.
    by case: H_in; left.
  contradict H_in'.
  apply: IH.
  move => H_in'.
  case: H_in.
  by right.
apply: IH.
move => H_in'.
case: H_in.
by right.
Qed.

Lemma nodup_msg_for :
  forall (h : @name base_fst multi_fst) m ns,
    NoDup ns ->
    NoDup (msg_for m (adjacent_to_node h ns)).
Proof.
move => h m.
elim => //=.
  move => H_nd.
  exact: NoDup_nil.
move => n ns IH H_in.
inversion H_in.
case (adjacent_to_dec _ _) => H_dec.
  rewrite /=.
  apply NoDup_cons.
    apply IH in H2.
    exact: not_in_msg_for.
  exact: IH.
exact: IH.
Qed.

Lemma nodup_msg_for_snd :
  forall h m ns,
    NoDup ns ->
    NoDup (msg_for m (adjacent_to_node h ns)).
Proof.
move => h m.
elim => //=.
  move => H_nd.
  exact: NoDup_nil.
move => n ns IH H_in.
inversion H_in.
case (adjacent_to_dec _ _) => H_dec.
  rewrite /=.
  apply NoDup_cons.
    apply IH in H2.
    exact: not_in_msg_for_snd.
  exact: IH.
exact: IH.
Qed.

Lemma snd_eq_not_in :
  forall l n m,
  (forall nm, In nm l -> snd nm = m) ->
  ~ In (n, m) l ->
  ~ In n (map (fun nm : name * msg => fst nm) l).
Proof.
elim => //.
case => n m l IH n' m' H_in H_in'.
rewrite /= => H_in_map.
case: H_in_map => H_in_map.
  case: H_in'.
  left.
  rewrite -H_in_map.
  have H_in' := H_in (n, m).
  rewrite -H_in' //.
  by left.
contradict H_in_map.
apply: (IH _ m').
  move => nm H_inn.
  apply: H_in.
  by right.
move => H_inn.
case: H_in'.
by right.
Qed.

Lemma nodup_snd_fst :
  forall nms,
    NoDup nms ->
    (forall nm nm', In nm nms -> In nm' nms -> snd nm = snd nm') ->
    NoDup (map (fun nm : name * msg => fst nm) nms).
Proof.
elim => //=.
  move => H_nd H_eq.
  exact: NoDup_nil.
case => n m l IH H_nd H_in.
inversion H_nd.
rewrite /=.
apply NoDup_cons.
  have H_snd: forall nm, In nm l -> snd nm = m.
    move => nm H_in_nm.
    have ->: m = snd (n, m) by [].
    apply H_in; first by right.
    by left.    
  exact: (@snd_eq_not_in _ _ m).
apply IH => //.
move => nm nm' H_in_nm H_in_nm'.
apply H_in => //.
  by right.
by right.
Qed.

Lemma tot_map_in_snd :
forall h m ns nm,
   In nm
     (map
        (fun nm0 : name * msg =>
         (tot_map_name (fst nm0), tot_map_msg (snd nm0)))
        (msg_for m (adjacent_to_node h ns))) ->
   snd nm = tot_map_msg m.
Proof.
move => h m.
elim => //=.
move => n ns IH.
case (adjacent_to_dec _ _) => H_dec /=.
  case => n' m' H_in.
  case: H_in => H_in.
    by inversion H_in.
  exact: IH.
exact: IH.
Qed.

Lemma tot_map_in_in :
  forall n m l,
  (forall nm, In nm l -> snd nm = m) ->
  ~ In (n, m) l ->
  ~ In (tot_map_name n, tot_map_msg m) (map (fun nm : name * msg => (tot_map_name (fst nm), tot_map_msg (snd nm))) l).
Proof.
move => n m.
elim => //=.
case => /= n' m' l IH H_eq H_in.
move => H_in'.
case: H_in' => H_in'.
  inversion H_in'.
  have H_nm := H_eq (n', m').
  rewrite /= in H_nm.
  case: H_in.
  left.
  apply tot_map_name_injective in H0.
  rewrite H0.
  rewrite H_nm //.
  by left.
contradict H_in'.
apply: IH.
  move => nm H_in_nm.
  apply: H_eq.
  by right.
move => H_in_nm.
case: H_in.
by right.
Qed.

Lemma msg_in_map :
  forall m l n m',
(forall nm, In nm l -> snd nm = m) ->
In (tot_map_name n, tot_map_msg m') (map (fun nm : name * msg => (tot_map_name (fst nm), tot_map_msg (snd nm))) l) ->
tot_map_msg m' = tot_map_msg m.
Proof.
move => m.
elim => //=.
case => /= n m' l IH n' m0 H_in H_in_map.
have H_in_f := H_in (n, m').
rewrite /= in H_in_f.
case: H_in_map => H_in_map.
  inversion H_in_map.
  rewrite H_in_f //.
  by left.
move: H_in_map.
apply: IH.
move => nm H_in'.
apply: H_in.
by right.
Qed.

Lemma nodup_tot_map :
  forall m nms,
  (forall nm, In nm nms -> snd nm = m) ->
  NoDup nms ->
  NoDup (map (fun nm : name * msg => (tot_map_name (fst nm), tot_map_msg (snd nm))) nms).
Proof.
move => m'.
elim => /=.
  move => H_fail H_nd.
  exact: NoDup_nil.
case => n m l IH H_fail H_nd.
inversion H_nd.
rewrite /=.
apply NoDup_cons.
  have H_f := H_fail (n, m).
  rewrite /= in H_f.
  move => H_in.
   have H_inf := @msg_in_map m' _ _ _ _ H_in.
   rewrite H_inf in H_in.
     contradict H_in.
     apply tot_map_in_in.
       move => nm H_in_nm.
       apply: H_fail.
       by right.
     rewrite H_f // in H1.
     by left.
   move => nm H_in_f.
   apply: H_fail.
   by right.
apply: IH => //.
move => nm H_in_nm.
apply: H_fail.
by right.
Qed.

Lemma in_for_msg :
  forall h m ns nm,
  In nm (msg_for m (adjacent_to_node h ns)) ->
  snd nm = m.
Proof.
move => h m.
elim => //.
move => n l IH.
case => /= n' m'.
case (adjacent_to_dec _ _) => H_dec.
  rewrite /=.
  move => H_in.
  case: H_in => H_in; first by inversion H_in.
  have ->: m' = snd (n', m') by [].
  exact: IH.
move => H_in.
have ->: m' = snd (n', m') by [].
exact: IH.
Qed.

Lemma in_msg_for_msg_fst :
  forall (h : @name base_fst multi_fst) m ns nm,
  In nm (msg_for m (adjacent_to_node h ns)) ->
  snd nm = m.
Proof.
move => h m.
elim => //.
move => n l IH.
case => /= n' m'.
case (adjacent_to_dec _ _) => H_dec.
  rewrite /=.
  move => H_in.
  case: H_in => H_in; first by inversion H_in.
  have ->: m' = snd (n', m') by [].
  exact: IH.
move => H_in.
have ->: m' = snd (n', m') by [].
exact: IH.
Qed.

Lemma in_tot_map_name :
forall m l n,
(forall nm, In nm l -> snd nm = m) ->
In (n, tot_map_msg m) (map (fun nm : name * msg => (tot_map_name (fst nm), tot_map_msg (snd nm))) l) ->
In (tot_map_name_inv n, m) l.
Proof.
move => m.
elim => //=.
case => /= n m' l IH n' H_in H_in'.
case: H_in' => H_in'.
  inversion H_in'.
  rewrite tot_map_name_inv_inverse.
  have H_nm := H_in (n, m').
  rewrite -H_nm /=; first by left.
  by left.
right.
apply: IH => //.
move => nm H_inn.
apply: H_in.
by right.
Qed.

Lemma in_msg_for_adjacent_to :
forall m ns failed h n,
In (tot_map_name_inv n, m) (msg_for m (adjacent_to_node h (exclude failed ns))) ->
In (tot_map_name_inv n) (adjacent_to_node h (exclude failed ns)).
Proof.
move => m.
elim => //=.
move => n l IH failed h n'. 
case (in_dec _ _ _) => H_dec; first exact: IH.
rewrite /=.
case (adjacent_to_dec _ _) => H_dec' /=.
  move => H_in.
  case: H_in => H_in.
    inversion H_in.
    by left.
  right.
  exact: IH.
exact: IH.
Qed.

Lemma in_adjacent_exclude_in_exlude :
  forall ns failed n h,
In (tot_map_name_inv n) (adjacent_to_node h (exclude failed ns)) ->
In (tot_map_name_inv n) (exclude failed ns) /\ adjacent_to h (tot_map_name_inv n).
Proof.
elim => //=.
move => n l IH failed n' h.
case (in_dec _ _ _) => /= H_dec.
  move => H_in.
  exact: IH.
case (adjacent_to_dec _ _) => /= H_dec'.
  move => H_in.
  case: H_in => H_in.
    rewrite {1}H_in -{4}H_in.
    split => //.
    by left.
  apply IH in H_in.
  move: H_in => [H_eq H_in].
  split => //.
  by right.
move => H_in.
apply IH in H_in.
move: H_in => [H_eq H_in].
split => //.
by right.
Qed.

Lemma in_failed_exclude :
  forall ns failed n,
  In (tot_map_name_inv n) (exclude failed ns) ->
  ~ In (tot_map_name_inv n) failed /\ In (tot_map_name_inv n) ns.
Proof.
elim => //=.
move => n ns IH failed n'.
case (in_dec _ _ _) => H_dec /=.
  move => H_in.
  apply IH in H_in.
  move: H_in => [H_in H_in'].
  split => //.
  by right.
move => H_in.
case: H_in => H_in.
  rewrite -{1}H_in {2}H_in.
  split => //.
  by left.
apply IH in H_in.
move: H_in => [H_in H_in'].
split => //.
by right.
Qed.

Lemma in_in_adj_msg_for :
      forall m ns failed n h,
    In n ns ->
    ~ In n (map tot_map_name failed) ->
    adjacent_to h n ->
    In (n, m)
     (msg_for m
        (adjacent_to_node h
           (exclude (map tot_map_name failed) ns))).
Proof.
move => m.
elim => //=.
move => n ns IH failed n' h H_in H_in' H_adj.
case (in_dec _ _ _) => H_dec.
  case: H_in => H_in; first by rewrite -H_in in H_in'.
  exact: IH.
case: H_in => H_in.
  rewrite H_in.
  rewrite /=.
  case (adjacent_to_dec _ _) => H_dec' //.
  rewrite /=.
  by left.
rewrite /=.
case (adjacent_to_dec _ _) => H_dec'.
  rewrite /=.
  right.
  exact: IH.
exact: IH.
Qed.

Lemma in_msg_for_adjacent_in :
  forall m ns n h,
  In (n, m) (msg_for m (adjacent_to_node h ns)) ->
  adjacent_to h n /\ In n ns.
Proof.
move => m.
elim => //=.
move => n ns IH n' h.
case (adjacent_to_dec _ _) => /= H_dec.
  move => H_in.
  case: H_in => H_in.
    inversion H_in.
    rewrite H0 in H_dec.
    split => //.
    by left.
  apply IH in H_in.
  move: H_in => [H_adj H_in].
  split => //.
  by right.
move => H_in.
apply IH in H_in.
move: H_in => [H_adj H_in].
split => //.
by right.
Qed.

Lemma in_exclude_not_in_failed_map :
  forall ns n failed,
  In n (exclude (map tot_map_name failed) ns) ->
  ~ In n (map tot_map_name failed) /\ In n ns.
Proof.
elim => //=.
move => n ns IH n' failed.
case (in_dec _ _ _) => H_dec.
  move => H_in.
  apply IH in H_in.
  move: H_in => [H_nin H_in].
  split => //.
  by right.
rewrite /=.
move => H_in.
case: H_in => H_in.
  rewrite H_in.
  rewrite H_in in H_dec.
  split => //.
  by left.
apply IH in H_in.
move: H_in => [H_nin H_in].
split => //.
by right.
Qed.

Lemma not_in_map_not_in_failed :
    forall failed n,
    ~ In n (map tot_map_name failed) ->
    ~ In (tot_map_name_inv n) failed.
Proof.
elim => //=.
move => n ns IH n' H_in H_in'.
case: H_in' => H_in'.
  case: H_in.
  left.
  by rewrite H_in' tot_map_name_inverse_inv.
contradict H_in'.
apply: IH.
move => H_in'.
case: H_in.
by right.
Qed.

Lemma in_tot_map_msg :
  forall m l n,
(forall nm, In nm l -> snd nm = m) ->
In (tot_map_name_inv n, m) l ->
In (n, tot_map_msg m) (map (fun nm : name * msg => (tot_map_name (fst nm), tot_map_msg (snd nm))) l).
Proof.
move => m.
elim => //=.
case => n m' /= l IH n' H_in H_in'.
case: H_in' => H_in'.
  inversion H_in'.
  left.
  by rewrite tot_map_name_inverse_inv.
right.
apply: IH => //.
move => nm H_inn.
apply: H_in.
by right.
Qed.

Lemma adjacent_in_in_msg :
  forall m ns n h,
    adjacent_to h (tot_map_name_inv n) ->
    In (tot_map_name_inv n) ns ->
    In (tot_map_name_inv n, m) (msg_for m (adjacent_to_node h ns)).
Proof.
move => m.
elim => //=.
move => n ns IH n' h H_adj H_in.
case (adjacent_to_dec _ _) => H_dec; case: H_in => H_in.
- rewrite /=.
  left.
  by rewrite H_in.
- rewrite /=.
  right.
  exact: IH.
- by rewrite H_in in H_dec.
- exact: IH.
Qed.

Lemma not_in_failed_in_exclude :
  forall ns n failed,
  ~ In (tot_map_name_inv n) failed ->
  In (tot_map_name_inv n) ns ->
  In (tot_map_name_inv n) (exclude failed ns).
Proof.
elim => //=.
move => n ns IH n' failed H_in H_in'.
case (in_dec _ _ _) => H_dec; case: H_in' => H_in'.
- by rewrite H_in' in H_dec.
- exact: IH.
- rewrite /=.
  by left.
- right.
  exact: IH.
Qed.

Hypothesis adjacent_to_fst_snd : 
  forall n n', adjacent_to n n' <-> adjacent_to (tot_map_name n) (tot_map_name n').

Lemma map_msg_for_eq :
  forall h m failed,
  Permutation 
    (map (fun nm : name * msg => (tot_map_name (fst nm), tot_map_msg (snd nm))) (msg_for m (adjacent_to_node h (exclude failed nodes)))) 
    (msg_for (tot_map_msg m) (adjacent_to_node (tot_map_name h) (exclude (map tot_map_name failed) nodes))).
Proof.
move => h m failed.
apply NoDup_Permutation; last split.
- apply (@nodup_tot_map m); first exact: in_msg_for_msg_fst.
  apply nodup_msg_for.
  apply nodup_exclude.
  exact: no_dup_nodes.
- apply nodup_msg_for_snd.
  apply nodup_exclude_snd.
  exact: no_dup_nodes.
- case: x => n m' H_in.
  have H_eq := tot_map_in_snd _ _ _ _ H_in.
  rewrite /= in H_eq.
  rewrite H_eq in H_in.
  rewrite H_eq {H_eq}.
  apply in_tot_map_name in H_in.
    apply in_msg_for_adjacent_to in H_in.
    apply in_adjacent_exclude_in_exlude in H_in.
    move: H_in => [H_in H_adj].
    apply in_failed_exclude in H_in.
    move: H_in => [H_in H_in'].
    have H_nin: ~ In n (map tot_map_name failed).
      rewrite -(tot_map_name_inverse_inv n).
      exact: not_in_failed_not_in.
    apply adjacent_to_fst_snd in H_adj.
    rewrite tot_map_name_inverse_inv in H_adj.
    have H_inn: In n nodes by exact: all_names_nodes.
    exact: in_in_adj_msg_for.
  exact: in_msg_for_msg_fst.
- case: x => n m' H_in.
  have H_eq := in_for_msg _ _ _ _ H_in.
  rewrite /= in H_eq.
  rewrite H_eq.
  rewrite H_eq in H_in.
  apply in_msg_for_adjacent_in in H_in.
  move: H_in => [H_adj H_in].
  rewrite -(tot_map_name_inverse_inv n) in H_adj.
  apply adjacent_to_fst_snd in H_adj.
  apply in_exclude_not_in_failed_map in H_in.
  move: H_in => [H_in_f H_in].
  apply not_in_map_not_in_failed in H_in_f.
  have H_in_n: In (tot_map_name_inv n) nodes by exact: all_names_nodes.
  apply in_tot_map_msg; first by move => nm; apply in_msg_for_msg_fst.
  apply adjacent_in_in_msg => //.
  exact: not_in_failed_in_exclude.
Qed.

Context {fail_msg_fst : FailMsgParams multi_fst}.
Context {fail_msg_snd : FailMsgParams multi_snd}.

Hypothesis fail_msg_fst_snd : msg_fail = tot_map_msg msg_fail.

Lemma map_msg_fail_eq :
  forall h failed,
  Permutation 
    (map (fun nm : name * msg => (tot_map_name (fst nm), tot_map_msg (snd nm))) (msg_for msg_fail (adjacent_to_node h (exclude failed nodes)))) 
    (msg_for msg_fail (adjacent_to_node (tot_map_name h) (exclude (map tot_map_name failed) nodes))).
Proof.
move => h failed.
rewrite fail_msg_fst_snd.
exact: map_msg_for_eq.
Qed.

Definition tot_map_onet (onet : @ordered_network _ multi_fst) : @ordered_network _ multi_snd :=
mkONetwork (fun src dst => map tot_map_msg (onet.(onwPackets) (tot_map_name_inv src) (tot_map_name_inv dst)))
           (fun n => tot_map_data (onet.(onwState) (tot_map_name_inv n))).

Lemma map_msg_update2 : 
  forall f ms to from,
    (fun src dst => map tot_map_msg (update2 f from to ms (tot_map_name_inv src) (tot_map_name_inv dst))) =
    update2 (fun src0 dst0 : name => map tot_map_msg (f (tot_map_name_inv src0) (tot_map_name_inv dst0)))
        (tot_map_name from) (tot_map_name to) (map tot_map_msg ms).
Proof.
move => f ms to from.
apply functional_extensionality => src.
apply functional_extensionality => dst.
rewrite /update2 /=.
case (sumbool_and _ _ _ _) => H_dec; case (sumbool_and _ _ _ _) => H_dec' //.
  move: H_dec => [H_eq H_eq'].
  case: H_dec' => H_dec'.
    rewrite H_eq in H_dec'.
    by rewrite tot_map_name_inverse_inv in H_dec'.
  rewrite H_eq' in H_dec'.
  by rewrite tot_map_name_inverse_inv in H_dec'.
move: H_dec' => [H_eq H_eq'].
case: H_dec => H_dec.
  rewrite -H_eq in H_dec.
  by rewrite tot_map_name_inv_inverse in H_dec.
rewrite -H_eq' in H_dec.
by rewrite tot_map_name_inv_inverse in H_dec.
Qed.

Lemma collate_tot_map_eq :
  forall f h l,
    (fun src dst => map tot_map_msg (collate h f l (tot_map_name_inv src) (tot_map_name_inv dst))) =
    collate (tot_map_name h) (fun src dst => map tot_map_msg (f (tot_map_name_inv src) (tot_map_name_inv dst))) (tot_map_name_msgs l).
Proof.
move => f h l.
elim: l h f => //.
case => n m l IH h f.
rewrite /= IH /=.
rewrite 2!tot_map_name_inv_inverse /=.
set f1 := fun _ _ => _.
set f2 := update2 _ _ _ _.
have H_eq_f: f1 = f2.
  rewrite /f1 /f2 {f1 f2}.
  have H_eq := map_msg_update2 f (f h n ++ [m]) n h.
  rewrite map_app in H_eq.
  by rewrite H_eq.
by rewrite H_eq_f.
Qed.

Lemma collate_tot_map_update2_eq :
  forall f from to ms l,
    (fun src dst => map tot_map_msg
            (collate to (update2 f from to ms) l
               (tot_map_name_inv src) (tot_map_name_inv dst))) =
    collate (tot_map_name to)
            (update2
               (fun src dst : name =>
                map tot_map_msg
                  (f (tot_map_name_inv src) (tot_map_name_inv dst))) (tot_map_name from)
               (tot_map_name to) (map tot_map_msg ms)) (tot_map_name_msgs l).
Proof.
move => f from to ms l.
rewrite -map_msg_update2.
by rewrite collate_tot_map_eq.
Qed.

Theorem step_o_f_tot_mapped_simulation_1 :
  forall net net' failed failed' tr,
    @step_o_f _ _ overlay_fst fail_msg_fst (failed, net) (failed', net') tr ->
    @step_o_f _ _ overlay_snd fail_msg_snd (map tot_map_name failed, tot_map_onet net) (map tot_map_name failed', tot_map_onet net') (map tot_map_trace_occ tr).
Proof.
move => net net' failed failed' tr H_step.
invcs H_step.
- rewrite /tot_map_onet /=.
  apply (@SOF_deliver _ _ _ _ _ _ _ (tot_map_msg m) (map tot_map_msg ms) _ (tot_map_data d) (tot_map_name_msgs l) (tot_map_name from)).
  * by rewrite /tot_map_net /= 2!tot_map_name_inv_inverse /= H3.
  * exact: not_in_failed_not_in.
  * rewrite /= tot_map_name_inv_inverse -tot_net_handlers_eq /tot_mapped_net_handlers /=.
    repeat break_let.
    by inversion H6.
  * by rewrite /= tot_map_update_eq collate_tot_map_update2_eq.
- rewrite /tot_map_onet /=.
  apply (@SOF_input _ _ _ _ _ _ _ _ _ _ (tot_map_data d) (tot_map_name_msgs l)).
  * exact: not_in_failed_not_in.
  * rewrite /= tot_map_name_inv_inverse -tot_input_handlers_eq /tot_mapped_input_handlers.
    repeat break_let.
    by inversion H5.
  * by rewrite /= /tot_map_onet /= tot_map_update_eq collate_tot_map_eq.
- rewrite /tot_map_onet /=.  
  set l := msg_for _ _.
  have H_nd: NoDup (map (fun nm => fst nm) (tot_map_name_msgs l)).
    rewrite /tot_map_name_msgs /=.
    rewrite /l {l}.
    apply nodup_snd_fst.
      apply (@nodup_tot_map msg_fail); first exact: in_msg_for_msg_fst.
      apply nodup_msg_for.
      apply nodup_exclude.
      exact: no_dup_nodes.
    move => nm nm' H_in H_in'.
    have H_fail := tot_map_in_snd _ _ _ _ H_in.
    have H_fail' := tot_map_in_snd _ _ _ _ H_in'.
    by rewrite H_fail H_fail'.
  have H_pm := map_msg_fail_eq h failed.
  have H_eq := @nodup_perm_collate_eq _ _ _ _ H_nd H_pm.
  rewrite /l /tot_map_name_msgs in H_eq.
  apply: SOF_fail.
  * exact: not_in_failed_not_in.
  * rewrite /=.
    rewrite /l collate_tot_map_eq /tot_map_name_msgs.
    by rewrite H_eq.
Qed.

End TotalMapSimulations.