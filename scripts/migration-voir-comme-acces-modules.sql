-- Voir comme : renvoyer aussi acces_modules, sinon le portail retombe sur la regle par role
-- et affiche des modules que la personne ne voit pas en vrai (ex. Controle caisse pour Carole).
-- Idempotent (CREATE OR REPLACE), seul le RETURN change.
CREATE OR REPLACE FUNCTION public.pbt_admin_voir_comme(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_admin uuid := public.pbt_user_id();
    v_user  public.users%ROWTYPE;
BEGIN
    IF public.pbt_role() IS DISTINCT FROM 'admin' THEN RAISE EXCEPTION 'reserve a l administrateur'; END IF;
    SELECT * INTO v_user FROM public.users WHERE id = p_user_id AND actif = true;
    IF v_user.id IS NULL THEN RAISE EXCEPTION 'utilisateur introuvable'; END IF;
    UPDATE pbt_private.sessions SET revoque_le = now()
    WHERE auth_uid = auth.uid() AND revoque_le IS NULL;
    INSERT INTO pbt_private.sessions (auth_uid, user_id, impersonne_par, expire_le)
    VALUES (auth.uid(), p_user_id, v_admin, now() + interval '2 hours');
    RETURN jsonb_build_object('id', v_user.id, 'nom', v_user.nom,
        'initiales', v_user.initiales, 'role', v_user.role, 'equipe', v_user.equipe,
        'acces_modules', v_user.acces_modules);
END $function$;
