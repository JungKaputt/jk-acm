window.orgData = null;
let quillAnnounce = null;
let quillRules = null;
let isQuillInit = false;

window.initOrgEditors = function() {
    if (isQuillInit) return;
    
    var toolbarOptions = [ 
        ['bold', 'italic', 'underline', 'strike'], 
        [{ 'list': 'ordered'}, { 'list': 'bullet' }], 
        [{ 'header': [1, 2, false] }], 
        ['clean'] 
    ];
    
    quillAnnounce = new Quill('#editor-announce', { 
        theme: 'snow', 
        modules: { toolbar: toolbarOptions }, 
        placeholder: 'Write announcement here...' 
    });
    
    quillRules = new Quill('#editor-rules', { 
        theme: 'snow', 
        modules: { toolbar: toolbarOptions }, 
        placeholder: 'List organization rules...' 
    });
    
    isQuillInit = true;
}

window.openOrgApp = function(hasOrg) {
    $("#win-om").fadeIn(200);
    
    if (hasOrg) {
        $("#om-create-page").hide();
        $("#om-main-layout").show();
        window.initOrgEditors(); 
        window.loadOMData();
    } else {
        $("#om-main-layout").hide();
        $("#om-create-page").css("display", "flex");
    }
}

window.switchOMTab = function(tab) {
    $(".om-tab").removeClass("active");
    $(".om-page").hide();
    
    if(tab == 'dash') $(".om-tab:eq(0)").addClass("active");
    if(tab == 'members') $(".om-tab:eq(1)").addClass("active");
    // NEW TAB HANDLING
    if(tab == 'requests') $(".om-tab:eq(2)").addClass("active");
    if(tab == 'treasury') $(".om-tab:eq(3)").addClass("active");
    if(tab == 'settings') $(".om-tab:eq(4)").addClass("active");
    
    $("#om-" + tab).show();
}

window.loadOMData = function() {
    $("#om-org-name").text("Loading...");
    $.post('https://jk-acm/getFullOrgData', JSON.stringify({}), function(data) {
        if(!data || !data.org) {
            $("#om-main-layout").hide();
            $("#om-create-page").css("display", "flex");
            return;
        }
        window.orgData = data;
        renderOM();
    });
}

function renderOM() {
    if(!window.orgData) return;
    let data = window.orgData;
    
    $("#om-org-name").text(data.org.label || "Unknown Org");
    
    // --- PROFILE, SLOGAN, LOGO, COLOR ---
    if(data.org.slogan && data.org.slogan !== "null") {
        $("#om-org-slogan").text('"' + data.org.slogan + '"');
        $("#edit-org-slogan").val(data.org.slogan);
    } else {
        $("#om-org-slogan").text("Established 2024");
        $("#edit-org-slogan").val("");
    }

    if(data.org.logo && data.org.logo.length > 5 && data.org.logo !== "null") {
        $("#om-logo-container").html(`<img src="${data.org.logo}" style="width:100%; height:100%; object-fit:cover; border-radius:12px;">`);
        $("#edit-org-logo").val(data.org.logo);
    } else {
        $("#om-logo-container").html('<i class="fas fa-fingerprint"></i>');
        $("#edit-org-logo").val("");
    }

    let orgColor = data.org.color || "#6c5ce7";
    $("#edit-org-color").val(orgColor);
    
    let win = document.getElementById("win-om");
    if(win) {
        win.style.setProperty('--accent', orgColor);
        win.style.setProperty('--accent-hover', adjustColorBrightness(orgColor, -20));
    }
    // ------------------------------------

    let formattedBal = "$" + (data.org.balance || 0).toLocaleString();
    
    $("#om-balance").text(formattedBal);
    $("#om-treasury-bal").text(formattedBal);
    $("#om-member-count").text(data.members ? data.members.length : 0);
    
    $("#om-announce-text").html(data.org.announcements || "No encrypted messages.");
    $("#om-rules-text").html(data.org.rules || "No protocols established.");

    // MEMBERS RENDER
    $("#member-list-container").empty();
    if (data.members) {
        data.members.forEach(m => {
            let actions = '<div class="action-group">';
            if (data.myGrade > m.grade) {
                actions += `<div class="btn-action promote" onclick="manageMember('${m.citizenid}', 'promote')" title="Promote"><i class="fas fa-chevron-up"></i></div>`;
                actions += `<div class="btn-action demote" onclick="manageMember('${m.citizenid}', 'demote')" title="Demote"><i class="fas fa-chevron-down"></i></div>`;
                actions += `<div class="btn-action kick" onclick="manageMember('${m.citizenid}', 'kick')" title="Kick"><i class="fas fa-user-times"></i></div>`;
            } else if (data.myGrade == m.grade && m.citizenid == data.members[0].citizenid) {
                actions += '<small style="color:#aaa; align-self:center;">(You)</small>';
            } else {
                actions += '<small style="color:#444; align-self:center;">-</small>';
            }
            actions += '</div>';

            $("#member-list-container").append(`
                <div class="member-row">
                    <span><i class="fas fa-user" style="color:#555; margin-right:8px;"></i> ${m.name}</span>
                    <span style="color:var(--accent);">Rank ${m.grade}</span>
                    ${actions}
                </div>
            `);
        });
    }
    
    // --- [NEW] RENDER REQUESTS ---
    $("#requests-list-container").empty();
    if (data.applications && data.applications.length > 0) {
        data.applications.forEach(app => {
            let html = `
                <div class="member-row" style="display:flex; flex-direction:column; align-items:flex-start; gap:10px; background:rgba(255,255,255,0.03);">
                    <div style="display:flex; justify-content:space-between; width:100%; align-items:center;">
                        <span style="font-weight:700; color:white; font-size:14px;">
                            <i class="fas fa-user-clock" style="color:var(--accent); margin-right:8px;"></i> ${app.name}
                        </span>
                        <span style="font-size:10px; color:#666;">${new Date(app.created_at).toLocaleDateString()}</span>
                    </div>
                    
                    <div style="background:rgba(0,0,0,0.3); padding:10px; border-radius:6px; width:100%; color:#a4b0be; font-size:13px; font-style:italic; border-left:2px solid var(--accent);">
                        "${app.message}"
                    </div>

                    <div style="display:flex; gap:10px; width:100%; margin-top:5px;">
                        <button class="btn-green" style="flex:1; font-size:11px; padding:8px;" onclick="handleApp(${app.id}, 'accept')">
                            <i class="fas fa-check"></i> ACCEPT RECRUIT
                        </button>
                        <button class="btn-red" style="flex:1; font-size:11px; padding:8px;" onclick="handleApp(${app.id}, 'reject')">
                            <i class="fas fa-times"></i> REJECT
                        </button>
                    </div>
                </div>
            `;
            $("#requests-list-container").append(html);
        });
    } else {
        $("#requests-list-container").html(`
            <div style="text-align:center; padding:40px; color:#555;">
                <i class="fas fa-inbox" style="font-size:32px; margin-bottom:10px;"></i><br>
                No pending applications.
            </div>
        `);
    }
    // ----------------------------

    $("#treasury-logs").empty();
    if(data.logs && data.logs.length > 0) {
        data.logs.forEach(l => {
            let incomeActions = ['Deposit', 'Laundry Tax', 'Turf Profit']; 
            let isIncome = incomeActions.includes(l.action);
            let typeClass = isIncome ? 'depo' : 'wd';
            let amountClass = isIncome ? 'text-green' : 'text-red';
            let sign = isIncome ? '+' : '-';
            
            $("#treasury-logs").append(`
                <div class="log-item ${typeClass}">
                    <div class="log-left">
                        <span class="log-action">${l.action}</span>
                        <span class="log-detail">${l.name} - ${l.details}</span>
                    </div>
                    <div class="log-right">
                        <span class="log-amount ${amountClass}">${sign}$${l.amount.toLocaleString()}</span>
                    </div>
                </div>
            `);
        });
    } else {
        $("#treasury-logs").html('<div style="padding:20px; color:#555; text-align:center;">No transaction history found.</div>');
    }

    if(quillAnnounce && quillAnnounce.root.innerHTML == '<p><br></p>') quillAnnounce.root.innerHTML = data.org.announcements || "";
    if(quillRules && quillRules.root.innerHTML == '<p><br></p>') quillRules.root.innerHTML = data.org.rules || "";
    
    renderPermissions(data.permissions || {});
    renderDangerZone();
}

function renderDangerZone() {
    $(".danger-zone").empty();
    let html = '';
    if (window.orgData.myGrade == 5) {
        html = `<h3><i class="fas fa-radiation"></i> Danger Zone (BOSS)</h3><p style="color:#aaa; font-size:13px; margin-bottom:15px;">WARNING: This action is permanent.</p><button class="btn-red full-width" onclick="disbandOrg()">PERMANENTLY DISBAND ORGANIZATION</button>`;
    } else {
        html = `<h3><i class="fas fa-sign-out-alt"></i> Danger Zone</h3><p style="color:#aaa; font-size:13px; margin-bottom:15px;">Leaving organization will revoke access.</p><button class="btn-red full-width" onclick="leaveOrg()">LEAVE ORGANIZATION</button>`;
    }
    $("#danger-zone-container").html(html);
}

function renderPermissions(perms) {
    $("#perm-container").empty();
    let table = `<table class="perm-table"><thead><tr><th>Rank</th><th>Depo</th><th>WD</th><th>Invite</th><th>Kick</th><th>Promote</th><th>Laundry</th><th>B.Market</th></tr></thead><tbody>`;
    for(let i=1; i<=4; i++) {
        let p = perms[i] || {};
        table += `<tr>
            <td>Rank ${i}</td>
            <td><input type="checkbox" class="perm-check" data-rank="${i}" data-type="deposit" ${p.deposit?'checked':''}></td>
            <td><input type="checkbox" class="perm-check" data-rank="${i}" data-type="withdraw" ${p.withdraw?'checked':''}></td>
            <td><input type="checkbox" class="perm-check" data-rank="${i}" data-type="invite" ${p.invite?'checked':''}></td>
            <td><input type="checkbox" class="perm-check" data-rank="${i}" data-type="kick" ${p.kick?'checked':''}></td>
            <td><input type="checkbox" class="perm-check" data-rank="${i}" data-type="promote" ${p.promote?'checked':''}></td>
            <td><input type="checkbox" class="perm-check" data-rank="${i}" data-type="laundry" ${p.laundry?'checked':''}></td>
            <td><input type="checkbox" class="perm-check" data-rank="${i}" data-type="blackmarket" ${p.blackmarket?'checked':''}></td>
        </tr>`;
    }
    table += `</tbody></table>`;
    $("#perm-container").html(table);
}

window.createOrg = function() {
    let name = $("#new-org-name").val();
    if(name && name.length > 3) {
        $.post('https://jk-acm/createOrg', JSON.stringify({ name: name }));
    }
}

window.manageMember = function(cid, action) {
    $.post('https://jk-acm/manageMember', JSON.stringify({ targetCid: cid, action: action }));
}

window.invitePlayer = function() {
    let tid = $("#invite-id").val();
    if(tid) {
        $.post('https://jk-acm/inviteMember', JSON.stringify({ targetId: tid }));
        $("#invite-id").val("");
    }
}

window.leaveOrg = function() {
    $.post('https://jk-acm/leaveOrg', JSON.stringify({}));
    window.closeApp('om');
}

window.disbandOrg = function() {
    $.post('https://jk-acm/disbandOrg', JSON.stringify({}));
    window.closeApp('om');
}

window.treasuryAction = function(type) {
    let amt = $("#treasury-amount").val();
    if(amt > 0) {
        $.post('https://jk-acm/treasuryAction', JSON.stringify({ type: type, amount: amt }));
        $("#treasury-amount").val("");
    }
}

window.saveInfoSettings = function() {
    let ann = quillAnnounce.root.innerHTML;
    let rul = quillRules.root.innerHTML;
    $.post('https://jk-acm/saveSettings', JSON.stringify({ type: 'info', announce: ann, rules: rul }));
}

window.saveProfileSettings = function() {
    let logo = $("#edit-org-logo").val();
    let slogan = $("#edit-org-slogan").val();
    let color = $("#edit-org-color").val();
    
    if(logo && logo.length > 0 && !logo.startsWith("http")) {
        console.log("Invalid Logo URL");
        return; 
    }

    $.post('https://jk-acm/saveSettings', JSON.stringify({ 
        type: 'profile', 
        logo: logo, 
        slogan: slogan,
        color: color
    }));
}

window.savePermSettings = function() {
    let newPerms = {};
    $(".perm-check").each(function() {
        let r = $(this).data('rank');
        let t = $(this).data('type');
        let v = $(this).is(':checked');
        if(!newPerms[r]) newPerms[r] = {};
        newPerms[r][t] = v;
    });
    newPerms['5'] = {deposit:true, withdraw:true, invite:true, kick:true, promote:true, laundry:true, blackmarket:true};
    $.post('https://jk-acm/saveSettings', JSON.stringify({ type: 'perms', perms: newPerms }));
}

// [NEW] Handle App Button
window.handleApp = function(appId, action) {
    $.post('https://jk-acm/handleApplication', JSON.stringify({
        appId: appId,
        action: action
    }));
}

function adjustColorBrightness(color, percent) {
    var num = parseInt(color.replace("#",""),16),
    amt = Math.round(2.55 * percent),
    R = (num >> 16) + amt,
    B = ((num >> 8) & 0x00FF) + amt,
    G = (num & 0x0000FF) + amt;
    return "#" + (0x1000000 + (R<255?R<1?0:R:255)*0x10000 + (B<255?B<1?0:B:255)*0x100 + (G<255?G<1?0:G:255)).toString(16).slice(1);
}