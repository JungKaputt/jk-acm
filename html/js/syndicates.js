let pendingApplication = null; 

window.loadSyndicates = function() {
    $("#syndicate-list").html('<div style="width:100%; text-align:center; padding-top:100px;"><i class="fas fa-circle-notch fa-spin" style="font-size:30px; color:var(--accent);"></i><br><br><span style="color:#666; font-size:12px; letter-spacing:1px;">DECRYPTING NETWORK DATA...</span></div>');
    $("#total-orgs-count").text("0");

    $.post('https://jk-acm/getSyndicateList', JSON.stringify({}), function(data) {
        $("#syndicate-list").empty();
        
        if (!data || data.length === 0) {
            $("#syndicate-list").html('<div style="width:100%; text-align:center; color:#555; margin-top:50px;">No organizations found on the network.</div>');
            return;
        }

        $("#total-orgs-count").text(data.length);

        data.forEach(org => {
            let logoHtml = org.logo && org.logo.length > 5 
                ? `<img src="${org.logo}" onerror="this.style.display='none';">`
                : `<i class="fas fa-users-slash" style="opacity:0.3;"></i>`;
                
            let motto = org.slogan && org.slogan !== "null" ? `"${org.slogan}"` : "No public motto established.";
            let color = org.color || "#6c5ce7";
            let bossName = org.bossName || "Unknown";
            
            // --- BUTTON LOGIC WITH 'HAS APPLIED' CHECK ---
            let btnHtml = '';
            
            if (window.userHasOrg) {
                // If user is already in an org
                if (window.userOrgId == org.id) {
                    btnHtml = `<button class="btn-apply my-org disabled"><i class="fas fa-check-circle"></i> YOUR SYNDICATE</button>`;
                } else {
                    btnHtml = `<button class="btn-apply disabled"><i class="fas fa-ban"></i> MEMBER RESTRICTED</button>`;
                }
            } else {
                // If user is not in an org
                if (org.hasApplied) {
                    // Check if they already applied to THIS org
                    btnHtml = `<button class="btn-apply disabled" style="border-color:${color}; color:${color}; opacity:0.7; cursor:default;"><i class="fas fa-paper-plane"></i> APPLICATION SENT</button>`;
                } else {
                    // Available to apply
                    btnHtml = `<button class="btn-apply" onclick="openApplicationModal(${org.id}, '${org.label.replace(/'/g, "\\'")}')"><i class="fas fa-file-signature"></i> REQUEST AFFILIATION</button>`;
                }
            }

            let html = `
                <div class="syndicate-card" style="--org-color: ${color};">
                    <div class="syndicate-card-header">
                        <div class="synd-logo">${logoHtml}</div>
                        <div class="synd-info">
                            <h3 style="color:${color}; filter: brightness(1.3);">${org.label}</h3>
                            <div class="synd-motto">${motto}</div>
                        </div>
                    </div>
                    
                    <div class="synd-stats-grid">
                        <div class="stat-box-mini">
                            <label>Leader</label>
                            <span style="color:${color};"><i class="fas fa-crown" style="font-size:9px;"></i> ${bossName}</span>
                        </div>
                        <div class="stat-box-mini">
                            <label>Strength</label>
                            <span><i class="fas fa-users" style="font-size:9px; color:#666;"></i> ${org.memberCount} Members</span>
                        </div>
                        <div class="stat-box-mini">
                            <label>Status</label>
                            <span style="color:#2ecc71;"><i class="fas fa-shield-alt" style="font-size:9px;"></i> Verified</span>
                        </div>
                        <div class="stat-box-mini">
                            <label>ID</label>
                            <span style="color:#666;">NET-${org.id}</span>
                        </div>
                    </div>

                    ${btnHtml}
                </div>
            `;
            $("#syndicate-list").append(html);
        });
    });
}

window.openApplicationModal = function(id, name) {
    pendingApplication = id;
    $("#apply-org-name").text("Target: " + name);
    $("#apply-message").val(""); 
    
    $("#modal-apply").css({
        "display": "flex",
        "opacity": 0
    }).animate({
        opacity: 1
    }, 200, function() {
        $("#apply-message").focus();
    });
}

window.closeApplicationModal = function() {
    $("#modal-apply").animate({
        opacity: 0
    }, 200, function() {
        $(this).css("display", "none");
        pendingApplication = null;
    });
}

window.submitApplication = function() {
    if(!pendingApplication) return;
    
    let msg = $("#apply-message").val();
    
    if (!msg || msg.trim().length < 5) {
        $("#apply-message").addClass("error-shake"); 
        setTimeout(() => $("#apply-message").removeClass("error-shake"), 500);
        $("#apply-message").css("border-color", "#ff4757");
        setTimeout(() => $("#apply-message").css("border-color", ""), 1000);
        return;
    }

    $.post('https://jk-acm/applyToOrg', JSON.stringify({
        orgId: pendingApplication,
        message: msg
    }));
    
    closeApplicationModal();
}