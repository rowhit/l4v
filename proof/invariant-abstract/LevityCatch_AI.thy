(*
 * Copyright 2014, General Dynamics C4 Systems
 *
 * This software may be distributed and modified according to the terms of
 * the GNU General Public License version 2. Note that NO WARRANTY is provided.
 * See "LICENSE_GPLv2.txt" for details.
 *
 * @TAG(GD_GPL)
 *)

theory LevityCatch_AI
imports
  "./$L4V_ARCH/ArchLevityCatch_AI"
begin

context begin interpretation Arch .
requalify_facts
  aobj_ref_arch_cap

end

lemmas aobj_ref_arch_cap_simps[simp] = aobj_ref_arch_cap

lemma detype_arch_state :
  "arch_state (detype S s) = arch_state s"
  by (simp add: detype_def)

lemma obj_ref_elemD:
  "r \<in> obj_refs cap \<Longrightarrow> obj_refs cap = {r}"
  by (cases cap, simp_all)


definition
  "diminished cap cap' \<equiv> \<exists>R. cap = mask_cap R cap'"


lemma const_on_failure_wp : 
  "\<lbrace>P\<rbrace> m \<lbrace>Q\<rbrace>, \<lbrace>\<lambda>rv. Q n\<rbrace> \<Longrightarrow> \<lbrace>P\<rbrace> const_on_failure n m \<lbrace>Q\<rbrace>"
  apply (simp add: const_on_failure_def)
  apply wp
  apply simp
  done

lemma get_cap_id:
  "(v, s') \<in> fst (get_cap p s) \<Longrightarrow> (s' = s)"
  by (clarsimp simp: get_cap_def get_object_def in_monad 
                     split_def
              split: Structures_A.kernel_object.splits)


lemmas cap_irq_opt_simps[simp] = 
  cap_irq_opt_def [split_simps cap.split sum.split]

lemmas cap_irqs_simps[simp] =
    cap_irqs_def [unfolded cap_irq_opt_def, split_simps cap.split sum.split, simplified option.simps]


lemma all_eq_trans: "\<lbrakk> \<forall>x. P x = Q x; \<forall>x. Q x = R x \<rbrakk> \<Longrightarrow> \<forall>x. P x = R x"
  by simp


declare liftE_wp[wp]
declare case_sum_True[simp]
declare select_singleton[simp]

crunch_ignore (add: cap_swap_ext 
              cap_move_ext cap_insert_ext empty_slot_ext create_cap_ext
              do_extended_op)

lemma select_ext_weak_wp[wp]: "\<lbrace>\<lambda>s. \<forall>x\<in>S. Q x s\<rbrace> select_ext a S \<lbrace>Q\<rbrace>"
  apply (simp add: select_ext_def)
  apply (wp select_wp)
  apply simp
  done

lemma select_ext_wp[wp]:"\<lbrace>\<lambda>s. a s \<in> S \<longrightarrow> Q (a s) s\<rbrace> select_ext a S \<lbrace>Q\<rbrace>"
  apply (simp add: select_ext_def unwrap_ext_det_ext_ext_def)
  apply (wp select_wp)
  apply (simp add: unwrap_ext_det_ext_ext_def select_switch_det_ext_ext_def)
  done

(* FIXME: move *)
lemmas mapM_UNIV_wp = mapM_wp[where S="UNIV", simplified]

end
