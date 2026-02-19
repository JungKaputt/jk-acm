$(document).ready(function() {
    // Global State
    window.userHasOrg = false; 
    window.userOrgId = null;
    let clockInterval = null;

    // ======================================================================
    // EVENT LISTENER (LUA -> JS)
    // ======================================================================
    window.addEventListener('message', function(event) {
        let e = event.data;
        
        if (e.action === "open") {
            $("#laptop-frame").css("display", "flex").addClass("zoomIn");
            
            $(".glass-window").hide(); 
            $("#win-stash").hide(); 
            $("#desktop-content").show();
            
            $("#modal-amount").hide();
            $("#modal-pin").hide(); 
            $("#modal-rush").hide();
            $("#modal-apply").hide();
            
            updateClock();
            if (clockInterval) clearInterval(clockInterval);
            clockInterval = setInterval(updateClock, 1000);

            if (e.playerData && e.playerData.hasOrg) {
                window.userHasOrg = true;
                window.userOrgId = e.playerData.orgId;
                
                let charName = e.playerData.charName || "Boss";
                $("#dash-username").text(charName);
                $(".widget-greeting").text("Welcome Back,");
            } else {
                window.userHasOrg = false;
                window.userOrgId = null;
                $("#dash-username").text("Guest User");
                $(".widget-greeting").text("System Restricted");
            }
            
            updateDockLocks();
        } 
        
        else if (e.action === "close") {
            $("#laptop-frame").hide();
            $("#win-stash").fadeOut(150);
            $("#modal-pin").fadeOut(150); 
            $(".modal-overlay").hide();
            
            if (clockInterval) clearInterval(clockInterval);
        }

        else if (e.action === "orgCreated") {
            window.userHasOrg = true;
            updateDockLocks();
            openApp('om'); 
        }
        
        else if (e.action === "refreshData") {
            if($("#win-om").is(":visible") && typeof window.loadOMData === 'function') window.loadOMData();
            if($("#win-blackmarket").is(":visible") && typeof window.loadMarket === 'function') window.loadMarket();
            if($("#win-syndicates").is(":visible") && typeof window.loadSyndicates === 'function') window.loadSyndicates();
            if($("#win-turf").is(":visible") && typeof window.loadTurfData === 'function') window.loadTurfData();
        }

        else if (e.action === "refreshStash") {
            if($("#win-stash").is(":visible") && typeof window.refreshStashContent === 'function') {
                window.refreshStashContent();
            }
        }

        // [FIX] Perbaikan Notifikasi agar sesuai dengan cl_main.lua
        else if (e.action === "notify") {
            showNotification(e.msg, e.type);
        }
        // Jaga-jaga jika ada script lain pakai nama ini
        else if (e.action === "laptopNotify") {
            showNotification(e.message, e.type);
        }

        else if (e.action === "openStashWindow") {
            $("#laptop-frame").hide(); 
            if(typeof window.openStashUI === 'function') {
                window.openStashUI(e.id, e.label);
            }
        }

        else if (e.action === "openPinSetup") {
            $("#laptop-frame").hide();
            if(typeof window.openPinApp === 'function') {
                window.openPinApp('setup', { coords: e.coords });
            }
        }

        else if (e.action === "openPinAuth") {
            $("#laptop-frame").hide();
            if(typeof window.openPinApp === 'function') {
                window.openPinApp('auth', { id: e.stashId });
            }
        }
    });

    // ======================================================================
    // CORE FUNCTIONS
    // ======================================================================

    function showNotification(msg, type) {
        let icon = '<i class="fas fa-info-circle"></i>';
        let title = "System";
        
        if (type === 'error') {
            icon = '<i class="fas fa-exclamation-triangle"></i>';
            title = "Error";
        } else if (type === 'success') {
            icon = '<i class="fas fa-check-circle"></i>';
            title = "Success";
        }

        let id = Date.now();
        let html = `
            <div id="notif-${id}" class="os-notification ${type}">
                <div class="notif-icon">${icon}</div>
                <div class="notif-content">
                    <span class="notif-title">${title}</span>
                    <span class="notif-msg">${msg}</span>
                </div>
            </div>
        `;

        $("#os-notification-container").append(html);
        setTimeout(() => { $(`#notif-${id}`).addClass("show"); }, 100);
        setTimeout(() => {
            $(`#notif-${id}`).removeClass("show");
            setTimeout(() => { $(`#notif-${id}`).remove(); }, 500);
        }, 4000);
    }

    function updateDockLocks() {
        if (window.userHasOrg) {
            $(".dock-item").removeClass("locked");
        } else {
            $("#dock-bm, #dock-turf, #dock-laundry").addClass("locked");
        }
    }
    
    function updateClock() {
        let d = new Date();
        let hours = d.getHours();
        let mins = d.getMinutes();
        let timeStr = hours + ":" + (mins < 10 ? '0' : '') + mins;
        
        $("#topbar-clock, #widget-clock").text(timeStr);

        const options = { weekday: 'long', day: 'numeric', month: 'long' };
        $("#widget-date").text(d.toLocaleDateString('en-US', options));
    }

    // ======================================================================
    // NAVIGATION LOGIC (GLASS OS)
    // ======================================================================
    
    window.openApp = function(appName) {
        if (!window.userHasOrg) {
            if (appName !== 'om' && appName !== 'syndicates') {
                return;
            }
        }

        $(".glass-window").hide();

        if (appName === 'om') {
            $("#win-om").show();
            if(typeof window.openOrgApp === 'function') window.openOrgApp(window.userHasOrg);
        } 
        else if (appName === 'blackmarket') {
            $("#win-blackmarket").show();
            if(typeof window.loadMarket === 'function') window.loadMarket();
        } 
        else if (appName === 'turf') {
            $("#win-turf").show();
            if(typeof window.loadTurfData === 'function') window.loadTurfData();
        } 
        else if (appName === 'laundry') {
            $("#win-laundry").show();
            if(typeof window.loadLaundryData === 'function') window.loadLaundryData();
        } 
        else if (appName === 'syndicates') {
            $("#win-syndicates").show();
            if(typeof window.loadSyndicates === 'function') window.loadSyndicates();
        }
    }
    
    window.closeApp = function(appName) {
        $("#win-" + appName).fadeOut(200);
    }

    window.closePhone = function() {
        $.post('https://jk-acm/close', JSON.stringify({}));
    }

    window.closeStash = function() {
        $("#win-stash").fadeOut(200);
        $.post('https://jk-acm/closeStashUI', JSON.stringify({})); 
    }

    document.onkeyup = function(data) { 
        if (data.which == 27) { 
            if($("#modal-pin").is(":visible") && typeof window.closePinUI === 'function') {
                window.closePinUI();
            } 
            else if($("#modal-amount").is(":visible") && typeof window.closeModal === 'function') {
                window.closeModal();
            } else if($("#modal-rush").is(":visible") && typeof window.closeRushModal === 'function') {
                window.closeRushModal();
            } else if($("#modal-apply").is(":visible") && typeof window.closeApplicationModal === 'function') {
                window.closeApplicationModal();
            } 
            else if($("#win-stash").is(":visible")) {
                window.closeStash();
            } else {
                window.closePhone();
            }
        } 
    };
});