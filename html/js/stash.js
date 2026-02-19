let currentStashId = null;
let pendingMove = null;

window.openStashUI = function(id, stashLabel) {
    currentStashId = id;
    $("#win-stash").fadeIn(200);
    refreshStashContent();
    initDragAndDrop(); 
}

window.closeStash = function() {
    $("#win-stash").fadeOut(200);
    $.post('https://jk-acm/close', JSON.stringify({})); 
}

function refreshStashContent() {
    if(!currentStashId) return;
    
    $("#player-inv-list").html('<div style="padding:10px; color:#aaa;">Loading Inventory...</div>');
    $("#safe-inv-list").html('<div style="padding:10px; color:#aaa;">Loading Safe...</div>');
    
    $.post('https://jk-acm/getStashData', JSON.stringify({ stashId: currentStashId }), function(data) {
        renderInventory("#player-inv-list", data.playerItems, "deposit");
        renderInventory("#safe-inv-list", data.stashItems, "withdraw");
    });
}

function renderInventory(containerId, items, actionType) {
    $(containerId).empty();
    
    if(!items || items.length === 0) {
        $(containerId).html('<div style="padding:20px; color:#555; font-size:12px; text-align:center; width:100%;">Empty</div>');
        return;
    }

    items.forEach(item => {
        let imgUrl = `nui://qb-inventory/html/images/${item.image || item.name + '.png'}`;
        let qty = item.amount || item.count || 0;
        let label = item.label || item.name;

        let html = `
            <div class="stash-slot" 
                 data-action="${actionType}" 
                 data-name="${item.name}" 
                 data-count="${qty}" 
                 data-slot="${item.slot}"
                 data-label="${label}">
                 
                <div class="slot-count">${qty}</div>
                <div class="slot-img" style="background-image: url('${imgUrl}');"></div>
                <div class="slot-name">${label}</div>
            </div>
        `;
        $(containerId).append(html);
    });

    initDragAndDrop();
}

function initDragAndDrop() {
    $(".stash-slot").draggable({
        helper: "clone", 
        appendTo: "body", 
        revert: "invalid", 
        zIndex: 99999,
        start: function(event, ui) { 
            $(this).css("opacity", "0.5"); 
        },
        stop: function(event, ui) { 
            $(this).css("opacity", "1"); 
        }
    });

    $(".droppable-zone").droppable({
        accept: ".stash-slot",
        hoverClass: "ui-droppable-hover", 
        drop: function(event, ui) {
            let droppedItem = ui.draggable;
            let actionType = droppedItem.data("action"); 
            let targetType = $(this).data("type");       
            
            if (actionType === targetType) {
                let itemName = droppedItem.data("name");
                let maxAmount = droppedItem.data("count");
                let slot = droppedItem.data("slot");

                handleStashAction(actionType, itemName, maxAmount, slot);
            }
        }
    });
}

function handleStashAction(action, itemName, maxAmount, slot) {
    pendingMove = { 
        action: action, 
        itemName: itemName, 
        maxAmount: maxAmount, 
        slot: slot 
    };

    let titleText = action === 'deposit' ? "Store Item" : "Retrieve Item";
    $("#modal-title").text(titleText);
    $("#modal-desc").text(`Enter Quantity (Max: ${maxAmount})`);
    
    $("#modal-input-qty").val(1).attr("max", maxAmount);

    $("#modal-amount").css({
        "display": "flex",
        "opacity": 0
    }).animate({
        opacity: 1
    }, 150, function() {
        $("#modal-input-qty").focus();
    });
}

window.submitModal = function() {
    if(!pendingMove) return;
    
    let amount = parseInt($("#modal-input-qty").val());
    if(!amount || isNaN(amount) || amount <= 0) {
        closeModal();
        return;
    }

    if(amount > pendingMove.maxAmount) amount = pendingMove.maxAmount;

    $.post('https://jk-acm/handleStashMove', JSON.stringify({
        stashId: currentStashId,
        action: pendingMove.action,
        item: pendingMove.itemName,
        amount: amount,
        slot: pendingMove.slot
    }));
    
    closeModal();
}

window.closeModal = function() {
    $("#modal-amount").animate({
        opacity: 0
    }, 150, function() {
        $(this).css("display", "none");
    });
    pendingMove = null;
}

$(document).on('keyup', '#modal-input-qty', function (e) {
    if (e.key === 'Enter' || e.keyCode === 13) {
        if($("#modal-amount").css("opacity") > 0) {
            window.submitModal();
        }
    }
});

let pinState = {
    active: false,
    mode: null, 
    data: null 
};

window.openPinApp = function(mode, payload) {
    pinState.active = true;
    pinState.mode = mode;
    pinState.data = payload;

    $("#pin-input-display").val(""); 

    if (mode === 'setup') {
        $("#pin-ui-title").html('<i class="fas fa-cog"></i> Security Setup');
        $("#pin-ui-desc").text("Set a new 4-6 digit passcode");
    } else {
        $("#pin-ui-title").html('<i class="fas fa-lock"></i> Locked Storage');
        $("#pin-ui-desc").text("Authentication Required");
    }

    $("#modal-pin").css({
        "display": "flex",
        "opacity": 0
    }).animate({
        opacity: 1
    }, 200);
}

window.addPinDigit = function(digit) {
    if (!pinState.active) return;
    let currentVal = $("#pin-input-display").val();
    if (currentVal.length < 6) {
        $("#pin-input-display").val(currentVal + digit);
    }
}

window.clearPin = function() {
    $("#pin-input-display").val("");
}

window.closePinUI = function() {
    $("#modal-pin").animate({
        opacity: 0
    }, 200, function() {
        $(this).css("display", "none");
        pinState = { active: false, mode: null, data: null };
        $.post('https://jk-acm/close', JSON.stringify({})); 
    });
}

window.submitPinUI = function() {
    if (!pinState.active) return;

    let pin = $("#pin-input-display").val();
    
    if (!pin || pin.length < 4) {
        $("#pin-input-display").addClass("error");
        setTimeout(() => $("#pin-input-display").removeClass("error"), 500);
        return;
    }

    if (pinState.mode === 'setup') {
        $.post('https://jk-acm/finalizeStashSetup', JSON.stringify({
            coords: pinState.data.coords,
            pin: pin
        }));
    } else if (pinState.mode === 'auth') {
        $.post('https://jk-acm/verifyStashAuth', JSON.stringify({
            stashId: pinState.data.id,
            pin: pin
        }));
    }

    $("#modal-pin").fadeOut(200); 
    pinState.active = false;
}