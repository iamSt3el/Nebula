pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import QtQuick

Singleton{
    id: root
    
    property var workspaces: Hyprland.workspaces 

    function refreshToplevels(): void{ 
        Hyprland.refreshToplevels()
    }

    function getWorkspace(index: int): HyprlandWorkspace {
        for(var i = 0; i < workspaces.values.length; i++){
            if(workspaces.values[i].id === index){
                return workspaces.values[i]
            }
        }
        return null
    }

    // Hyprland reaps a workspace the moment it goes empty, so an id with no
    // HyprlandWorkspace behind it is normal — dispatch by id and Hyprland
    // creates it on the spot.
    function activateWorkspaceId(id): void {
        const ws = getWorkspace(id)
        if (ws) ws.activate()
        else Hyprland.dispatch(`hl.dsp.focus({ workspace = '${id}' })`)
    }

    // This machine runs a Lua Hyprland config, and under Lua the compositor
    // parses dispatch arguments as Lua expressions — the classic
    // `movetoworkspacesilent <id>,address:0x…` form is rejected outright with
    // "expected a dispatcher", whether it arrives via hyprctl or over IPC.
    // Verified against Hyprland 0.56.1: `hl.dsp.window.move` is the only window
    // move dispatcher (see /usr/share/hypr/stubs/hl.meta.lua) and `window =`
    // selects the target.
    function moveWindowToWorkspace(address, workspaceId): void {
        if (!address || !workspaceId) return
        // Quickshell reports the address bare; the selector wants it 0x-prefixed
        const addr = address.startsWith("0x") ? address : "0x" + address
        Hyprland.dispatch(
            `hl.dsp.window.move({ workspace = ${workspaceId}, window = "address:${addr}", silent = true })`)
    }

    // Check if any workspace in the given array is active
    function hasActiveWorkspace(workspaceIds): bool {
        for(var i = 0; i < workspaceIds.length; i++){
            var ws = getWorkspace(workspaceIds[i])
            if(ws && ws.active){
                return true
            }
        }
        return false
    }
}

