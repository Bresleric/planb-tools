// ============================================================================
// PlanB-Tools — Formules du controle de caisse (source unique)
// ----------------------------------------------------------------------------
// Utilise par : caisse/index.html (saisie + historique) et rapport/index.html
// (resultat du controle de caisse dans le rapport journalier).
// Les formules different entre Freddy et Liesel : ne les modifier QUE ici.
//
// d         = une ligne caisse_controle (ou le formulaire de saisie)
// cashDebut = comptage_caisse du jour precedent (fond de caisse de depart)
//
// Chargement (chemin RELATIF, cf. planb-common.js) :
//   <script src="../js/caisse-calc.js"></script>
// ============================================================================

(function (global) {
  'use strict';

  function n(v) { return parseFloat(v) || 0; }

  var freddy = {
    calcControleCA: function (d) {
      var totalCB = n(d.cb_sans_contact) + n(d.cb_emv) + n(d.cb_sans_contact_sg) + n(d.cb_emv_sg)
        + n(d.credit) + n(d.titres_restaurant) + n(d.amex);
      return n(d.ca) - n(d.plus_cash) - totalCB - n(d.plus_tr) - n(d.plus_chq_virement)
        + n(d.pourboire_cb) - n(d.click_collect) - n(d.compte_client);
    },
    calcTotalCB: function (d) {
      return n(d.cb_sans_contact) + n(d.cb_emv) + n(d.cb_sans_contact_sg) + n(d.cb_emv_sg)
        + n(d.credit) + n(d.titres_restaurant) + n(d.amex);
    },
    calcCaisseTheorique: function (d, cashDebut) {
      return n(cashDebut) + n(d.plus_cash) + n(d.prelevement) - n(d.pourboire_cb)
        - n(d.acomptes_verse) + n(d.depense_caisse) + n(d.ajout);
    },
    calcEcart: function (d, cashDebut) {
      var theo = freddy.calcCaisseTheorique(d, cashDebut);
      return theo - n(d.comptage_caisse) + n(d.pourboires);
    }
  };

  var liesel = {
    calcControleCA: function (d) {
      return n(d.ca) - n(d.plus_cash) - n(d.cb_emv) - n(d.cm_cic) - n(d.cb_sans_contact)
        - n(d.amex) - n(d.titres_restaurant) - n(d.compte_client) - n(d.plus_chq_virement)
        + n(d.pourboire_cb);
    },
    calcTotalCB: function (d) {
      return n(d.cb_emv) + n(d.cm_cic) + n(d.cb_sans_contact) + n(d.amex) + n(d.titres_restaurant);
    },
    calcCaisseTheorique: function (d, cashDebut) {
      return n(cashDebut) + n(d.plus_cash) - n(d.pourboire_cb)
        - n(d.acomptes_verse) - n(d.achats_divers) - n(d.prelevement) + n(d.ajout);
    },
    calcEcart: function (d, cashDebut) {
      var theo = liesel.calcCaisseTheorique(d, cashDebut);
      return n(d.comptage_caisse) - theo;
    }
  };

  global.CAISSE_CALC = { freddy: freddy, liesel: liesel };
})(window);
