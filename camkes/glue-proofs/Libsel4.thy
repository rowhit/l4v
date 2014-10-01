theory Libsel4 imports
  "../../tools/c-parser/CTranslation"
  "../../tools/autocorres/AutoCorres"
  "../../tools/autocorres/NonDetMonadEx"
begin

(* This theory contains some lemmas about libsel4 that are useful for CAmkES systems, but are likely
 * useful for other user-level reasoning on seL4 as well.
 *)

(* Load the fragment of libsel4 we need for reasoning about seL4_GetMR and seL4_SetMR. *)
install_C_file "libsel4.c"

autocorres [ts_rules=nondet, no_heap_abs=seL4_SetMR] "libsel4.c"

context libsel4 begin

abbreviation "seL4_MsgMaxLength \<equiv> 120"

lemma le_step_down:"\<lbrakk>(i::int) < n; i = n - 1 \<Longrightarrow> P; i < n - 1 \<Longrightarrow> P\<rbrakk> \<Longrightarrow> P"
  apply arith
  done

(* Avoid having to hold Isabelle's hand with "unat (of_int x)". *)
lemma unat_nat[simp]:"\<lbrakk>(i::int) \<ge> 0; i < seL4_MsgMaxLength\<rbrakk> \<Longrightarrow> unat ((of_int i)::sword32) = nat i"
  apply (erule le_step_down, simp, simp)+
  done

(* A manually abstracted version of seL4_SetMR. A future version of AutoCorres should translate
 * seL4_SetMR to this automatically.
 *)
definition
  seL4_SetMR_lifted' :: "int \<Rightarrow> word32 \<Rightarrow> (lifted_globals, unit) nondet_monad"
where
  "seL4_SetMR_lifted' i val \<equiv>
   do
     ret' \<leftarrow> seL4_GetIPCBuffer';
     guard (\<lambda>s. i < seL4_MsgMaxLength);
     guard (\<lambda>s. 0 \<le> i);
     modify (\<lambda>s. s \<lparr>heap_seL4_IPCBuffer__C := (heap_seL4_IPCBuffer__C s)(ret' :=
        msg_C_update  (
            \<lambda>a. Arrays.update a (nat i) val) (heap_seL4_IPCBuffer__C s ret')
          )  \<rparr>)
  od"

definition
  globals_frame_intact :: "lifted_globals \<Rightarrow> bool"
where
  "globals_frame_intact s \<equiv> is_valid_seL4_IPCBuffer__C'ptr s (Ptr (scast seL4_GlobalsFrame))"
definition
  ipc_buffer_valid :: "lifted_globals \<Rightarrow> bool"
where
  "ipc_buffer_valid s \<equiv> is_valid_seL4_IPCBuffer__C s
      (heap_seL4_IPCBuffer__C'ptr s (Ptr (scast seL4_GlobalsFrame)))"

(* seL4_GetMR and seL4_SetMR call seL4_GetIPCBuffer, so we're going to need a WP lemma about it. *)
lemma seL4_GetIPCBuffer_wp[THEN validNF_make_schematic_post, simplified]:
  "\<forall>s'. \<lbrace>\<lambda>s. globals_frame_intact s \<and>
             s = s'\<rbrace>
     seL4_GetIPCBuffer'
   \<lbrace>\<lambda>r s. r = heap_seL4_IPCBuffer__C'ptr s (Ptr (scast seL4_GlobalsFrame)) \<and>
          s = s'\<rbrace>!"
  apply (rule allI)
  apply (simp add:seL4_GetIPCBuffer'_def)
  apply wp
  apply (clarsimp simp:globals_frame_intact_def)
  done

(* Functional versions of seL4_SetMR and seL4_GetMR. See how these are used below for stating
 * transformations on states.
 *)
definition
  setMR :: "lifted_globals \<Rightarrow> nat \<Rightarrow> word32 \<Rightarrow> lifted_globals"
where
  "setMR s i v \<equiv>
      s\<lparr>heap_seL4_IPCBuffer__C := (heap_seL4_IPCBuffer__C s)
        (heap_seL4_IPCBuffer__C'ptr s (Ptr (scast seL4_GlobalsFrame)) :=
          msg_C_update (\<lambda>a. Arrays.update a i v)
            (heap_seL4_IPCBuffer__C s (heap_seL4_IPCBuffer__C'ptr s
              (Ptr (scast seL4_GlobalsFrame)))))\<rparr>"
definition
  getMR :: "lifted_globals \<Rightarrow> nat \<Rightarrow> word32"
where
  "getMR s i \<equiv>
       index (msg_C (heap_seL4_IPCBuffer__C s
            (heap_seL4_IPCBuffer__C'ptr s (Ptr (scast seL4_GlobalsFrame))))) i"

lemma getMR_setMR:
  "\<lbrakk>i < seL4_MsgMaxLength\<rbrakk> \<Longrightarrow> getMR (setMR s j v) i = (if i = j then v else getMR s i)"
  apply (simp add:getMR_def setMR_def fun_upd_def)
  done

lemma msg_update_id:"msg_C_update (\<lambda>r. Arrays.update r i (index (msg_C y) i)) y = y"
  apply (cut_tac f="(\<lambda>r. Arrays.update r i (index (msg_C y) i))" and
                 f'=id and r=y and r'=y in seL4_IPCBuffer__C_fold_congs(2))
     apply simp+
  apply (simp add:id_def) 
  apply (metis seL4_IPCBuffer__C_accupd_diff(22) seL4_IPCBuffer__C_accupd_diff(24)
               seL4_IPCBuffer__C_accupd_diff(26) seL4_IPCBuffer__C_accupd_diff(28)
               seL4_IPCBuffer__C_accupd_diff(30) seL4_IPCBuffer__C_accupd_diff(41)
               seL4_IPCBuffer__C_accupd_same(2) seL4_IPCBuffer__C_idupdates(1))
  done

lemma setMR_getMR:
  "setMR s i (getMR s i) = s"
  apply (simp add:setMR_def getMR_def)
  apply (subst msg_update_id)
  apply simp
  done

lemma if_fold:"(if P then Q else if P then R else S) = (if P then Q else S)"
  by presburger

lemma setMR_setMR[simp]:"setMR (setMR s i x) i y = setMR s i y"
  apply (simp add:setMR_def fun_upd_def)
  apply (subst if_fold)
  apply (subst comp_def, subst update_update)
  apply simp
  done

lemma seL4_GetMR_wp[wp_unsafe]:
  "\<lbrace>\<lambda>s. (i::int) \<ge> 0 \<and>
            i < seL4_MsgMaxLength \<and>
            globals_frame_intact s \<and>
            ipc_buffer_valid s \<and>
            P (getMR s (nat i)) s\<rbrace>
     seL4_GetMR' i
   \<lbrace>P\<rbrace>!"
  apply (simp add:seL4_GetMR'_def)
  apply (wp seL4_GetIPCBuffer_wp)
  apply (simp add:globals_frame_intact_def ipc_buffer_valid_def getMR_def)
  done

end

locale SetMR = libsel4 +
  (* This assumption should go away in future when the abstraction is performed automatically. *)
  assumes seL4_SetMR_axiom:"exec_concrete lift_global_heap (seL4_SetMR' i val) =
                                seL4_SetMR_lifted' i val"
begin

lemma seL4_SetMR_wp[wp_unsafe]:
  notes seL4_SetMR_axiom[simp]
  shows
  "\<lbrace>\<lambda>s. globals_frame_intact s \<and>
        ipc_buffer_valid s \<and>
        i \<ge> 0 \<and>
        i < seL4_MsgMaxLength \<and>
        (\<forall>x. P x (setMR s (nat i) v))\<rbrace>
     exec_concrete lift_global_heap (seL4_SetMR' i v)
   \<lbrace>P\<rbrace>!"
  apply (simp add:seL4_SetMR_lifted'_def)
  apply (wp seL4_GetIPCBuffer_wp)
  apply (simp add:setMR_def globals_frame_intact_def ipc_buffer_valid_def)
  done

(* When you write to a message register and then read back from the same register, you get the value
 * you wrote and the only state you have affected is that register.
 *)
lemma "\<forall>(i::int) x. \<lbrace>\<lambda>s. i \<ge> 0 \<and> i < seL4_MsgMaxLength \<and>
                         globals_frame_intact s \<and>
                         ipc_buffer_valid s \<and>
                         P (setMR s (nat i) x)\<rbrace>
         do exec_concrete lift_global_heap (seL4_SetMR' i x);
            seL4_GetMR' i
         od
             \<lbrace>\<lambda>r s. globals_frame_intact s \<and>
                    ipc_buffer_valid s \<and>
                    r = x \<and>
                    P s\<rbrace>!"
  apply (rule allI)+
  apply (wp seL4_GetMR_wp seL4_SetMR_wp)
  apply clarsimp
  apply (subst getMR_setMR)
   apply (erule le_step_down, simp, simp)+
  apply (simp add:setMR_def getMR_def globals_frame_intact_def ipc_buffer_valid_def)
  done

(* seL4_SetMR run twice on the same register is the same as just running the second invocation. *)
lemma "\<forall>(i::int) x y. \<lbrace>\<lambda>s. i \<ge> 0 \<and> i < seL4_MsgMaxLength \<and>
                           globals_frame_intact s \<and>
                           ipc_buffer_valid s \<and>
                           P (setMR s (nat i) y)\<rbrace>
         do exec_concrete lift_global_heap (seL4_SetMR' i x);
            exec_concrete lift_global_heap (seL4_SetMR' i y)
         od
             \<lbrace>\<lambda>_ s. globals_frame_intact s \<and>
                    ipc_buffer_valid s \<and>
                    P s\<rbrace>!"
  apply (rule allI)+
  apply (wp seL4_SetMR_wp)
  apply clarsimp
  apply (simp add:setMR_def globals_frame_intact_def ipc_buffer_valid_def)
  done

(* seL4_SetMR with the value that is already in that message register does nothing. *)
lemma "\<forall>(i::int) x s'. \<lbrace>\<lambda>s. i \<ge> 0 \<and> i < seL4_MsgMaxLength \<and>
                            globals_frame_intact s \<and>
                            ipc_buffer_valid s \<and>
                            x = getMR s (nat i) \<and>
                            s = s'\<rbrace>
          exec_concrete lift_global_heap (seL4_SetMR' i x)
        \<lbrace>\<lambda>_ s. s = s'\<rbrace>!"
  apply (rule allI)+
  apply (wp seL4_SetMR_wp)
  apply clarsimp
  apply (simp add:setMR_getMR)
  done

(* SetMRs on distinct registers can be reordered. You probably never want to use this lemma, but
 * it's nice to know it's true.
 *)
lemma "\<lbrakk> i \<noteq> j \<rbrakk> \<Longrightarrow> do exec_concrete lift_global_heap (seL4_SetMR' i x);
                    exec_concrete lift_global_heap (seL4_SetMR' j y)
                 od
               = do exec_concrete lift_global_heap (seL4_SetMR' j y);
                    exec_concrete lift_global_heap (seL4_SetMR' i x)
                 od"
  apply (subst seL4_SetMR_axiom)+
  apply (case_tac "i < 0 \<or> j < 0")
   apply (simp add:seL4_SetMR_lifted'_def seL4_GetIPCBuffer'_def bind_assoc seL4_GlobalsFrame_def)
   apply (monad_eq)
   apply (auto simp: fun_upd_def o_def split: split_if split_if_asm)[1]
  apply (simp add:seL4_SetMR_lifted'_def seL4_GetIPCBuffer'_def bind_assoc seL4_GlobalsFrame_def)
  apply (monad_eq)
  apply (auto simp: fun_upd_def o_def split: split_if split_if_asm)[1]
  done

definition
  messageInfo_new :: "word32 \<Rightarrow> word32 \<Rightarrow> word32 \<Rightarrow> word32 \<Rightarrow> word32"
where
  "messageInfo_new label capsUnwrapped extraCaps len \<equiv>
    (label && 0xFFFFF << 12) || (capsUnwrapped && 7 << 9) || (extraCaps && 3 << 7) || (len && 0x7F)"

lemma seL4_MessageInfo_new_wp[THEN validNF_make_schematic_post, simplified]:"\<forall>s'. \<lbrace>\<lambda>s. s = s'\<rbrace>
              seL4_MessageInfo_new' l c e len
            \<lbrace>\<lambda>r s. index (words_C r) 0 = messageInfo_new l c e len \<and> s = s'\<rbrace>!"
  apply (rule allI)
  apply (simp add:seL4_MessageInfo_new'_def)
  apply wp
  apply (clarsimp simp:messageInfo_new_def word_bw_comms word_bw_lcs)
  apply (metis (no_types, hide_lams) word_bw_assocs(2))
  done

end

end