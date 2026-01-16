-- TODO Clean this up, especially the settings
-- Not everything is localized

FriendXP = LibStub("AceAddon-3.0"):NewAddon("FriendXP", "AceBucket-3.0", "AceConsole-3.0", "AceEvent-3.0","AceComm-3.0", "AceSerializer-3.0", "AceTimer-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("FriendXP")
local LSM = LibStub("LibSharedMedia-3.0")
local LQT = LibStub("LibQTip-1.0")

local WoWClassic = select(4, GetBuildInfo()) < 20000 -- Addon runs on both clients as-is, this is to hide the XPDisabled stuff on classic

FriendXP.LSM = LSM

LSM:Register("background", "Wireless Icon", "Interface\\Addons\\FriendXP-Classic\\Artwork\\wlan_wizard.tga")
LSM:Register("background", "Wireless Icon2", "Interface\\Addons\\FriendXP-Classic\\Artwork\\wlan_wizard2.tga")
LSM:Register("background", "Wireless Incoming", "Interface\\Addons\\FriendXP-Classic\\Artwork\\wlan_incoming.tga")
LSM:Register("background", "PartyXPBar", "Interface\\Addons\\FriendXP-Classic\\Artwork\\partyxpbar.tga")
LSM:Register("border", "Thin Square 1px", "Interface\\Addons\\FriendXP-Classic\\Artwork\\Square 1px.tga")
LSM:Register("border", "Thin Square 2px", "Interface\\Addons\\FriendXP-Classic\\Artwork\\Square 2px.tga")
LSM:Register("background", "CircleXP", "Interface\\Addons\\FriendXP-Classic\\Artwork\\circlexp.tga")

local friends = { }; -- Needs renaming
local fonts = { };

local Miniframes = { };
local frameCache = { };

local Miniframe = nil;
local xpbar = nil;

local configGenerated = false;
local activeFriend = "";
-- local whatevers
local gsub = string.gsub


FriendXP.LDB = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject("FriendXP", {
 type = "launcher",
 label = "FriendXP",
 icon = "Interface\\ICONS\\INV_Misc_Gem_Variety_02.blp",
 OnClick = function(clickedFrame, button)
  if (button == "LeftButton") then
   FriendXP:SendXP()
  elseif (button == "RightButton") then
   if (configGenerated) then
    -- InterfaceOptionsFrame_OpenToCategory(FriendXP.configFrame) FIXME
   else
    FriendXP:WorldEnter()
   end
  end
 end,
})

-- Need to rework the options menu
local function giveOptions(self)
 local maxwidth = self:Round(UIParent:GetWidth(),0);
 local maxheight = self:Round(UIParent:GetHeight(),0);
 local db = self.db.profile -- To shorten some of the variables
 local options = {
 name = "FriendXP",
 type = "group",
 args = {
  enabled = {
   name = L["Enabled"],
   order = 1,
   type = "toggle",
   set = function(info, value) self.db.profile.enabled = value; if (value) then self:Enable() else self:Disable() end; end,
   get = function(info) return self.db.profile.enabled end
  },
  unlocked = {
   name = L["Toggle Lock"],
   desc = L["UnlockDesc"],
   type = "execute",
   func = function() FriendXP:ToggleLock() end,
  },
  debug = {
   name = L["Debug"],
   order = 2,
   type = "toggle",
   set = function(info, value) self.db.profile.debug = value end,
   get = function(info) return self.db.profile.debug end,
  },
  online = {
   name = L["Check Online Status"],
   desc = L["CheckOnlineDesc"],
   order = 3,
   type = "toggle",
   get = function(info) return self.db.profile.checkOnline end,
   set = function(info, value) self.db.profile.checkOnline = value end,
  },
  doLevelUp = {
   name = L["Level Up Message"],
   desc = L["LevelUpMessageDesc"],
   order = 4,
   type = "toggle",
   get = function(i) return self.db.profile.doLevelUp end,
   set = function(i, v) self.db.profile.doLevelUp = v end,
  },
  integrateParty = {
   name = L["IntegrateParty"],
   desc = L["IntegratePartyDesc"],
   type = "toggle",
   get = function(i) return self.db.profile.integrateParty end,
   set = function(i, v) self.db.profile.integrateParty = v; self:HookBlizzPartyFrames() end,
  },
  ignoreWhisper = {
   name = L["Ignore Whispers"],
   desc = L["IgnoreWhisper_Desc"],
   type = "toggle",
   get = function(i) return self.db.profile.ignoreWhisper end,
   set = function(i, v) self.db.profile.ignoreWhisper = v end,
  },
  onlyFriends = {
   name = L["Only allow friends"],
   desc = L["OnlyFriendsDesc"],
   type = "toggle",
   get = function(i) return self.db.profile.onlyFriends end,
   set = function(i, v) self.db.profile.onlyFriends = v end,
  },
  friendttl = {
   name = L["FriendTTL"],
   desc = L["FriendTTL_Desc"],
   type = "range",
   min = 10, max = 1800, step = 1,
   set = function(i, v) self.db.profile.miniframe.threshold = v end,
   get = function(i) return self.db.profile.miniframe.threshold end,
  },
  grid2 = {
	name = "Grid2",
	desc = L["Adds an xp percentage status to Grid2"],
	type = "toggle",
	set = function(i, v) self.db.profile.grid2 = v self:SetupGrid2() end,
	get = function(i) return self.db.profile.grid2 end,
  },
  sendoptions = {
   name = L["Broadcast To"],
   order = 0.9,
   type = "group",
   args = {
    friendAll = {
     name = L["SendFriends"],
     desc = L["SendFriendsDesc"],
     type = "toggle",
     get = function(i) return self.db.profile.sendAll end,
     set = function(i, v) self.db.profile.sendAll = v end,
    },
    partyAll = {
     name = L["SendParty"],
     desc = L["SendPartyDesc"],
     type = "toggle",
     get = function(i) return self.db.profile.partyAll end,
     set = function(i, v) self.db.profile.partyAll = v end,
    },
    bgAll = {
     name = L["SendBattleground"],
     desc = L["SendBattlegroundDesc"],
     type = "toggle",
     get = function(i) return self.db.profile.bgAll end,
     set = function(i, v) self.db.profile.bgAll = v end,
    },
    guildAll = {
     name = L["SendGuild"],
     desc = L["SendGuildDesc"],
     type = "toggle",
     get = function(i) return self.db.profile.guildAll end,
     set = function(i, v) self.db.profile.guildAll = v end,
    },
   },
  },
  friendbar = {
   name = L["FriendBar"],
   order = 1,
   type = "group",
   args = {
    enabled = {
     name = L["Enabled"],
     order = 1,
     type = "toggle",
     set = function(i, v) self.db.profile.friendbar.enabled = v; self:ToggleFriendbar() end,
     get = function(i) return self.db.profile.friendbar.enabled end,
    },
    personal = {
     name = L["Use as personal xp bar"],
	 desc = L["Will always show your experience"],
	 width = "full",
	 descStyle = "inline",
     order = 1.01,
     type = "toggle",
     set = function(i, v) self.db.profile.friendbar.personal = v end,
     get = function(i) return self.db.profile.friendbar.personal end,
    },
    fontheader = {
     name = L["Font"],
     order = 3,
     type = "header",
    },
    face = {
     name = L["FontFace"],
     order = 3.1,
     type = "select",
     values = LSM:HashTable("font"),
     dialogControl = "LSM30_Font",
     get = function(info) return self.db.profile.friendbar.text.font end,
     set = function(info, value) self.db.profile.friendbar.text.font = value; self:UpdateSettings() end,
    },
    style = {
     name = L["FontStyle"],
     order = 3.2,
     type = "select",
     style = "dropdown",
     values = { [""] = L["None"], ["OUTLINE"] = L["Outline"], ["THICKOUTLINE"] = L["Thick Outline"], ["MONOCHROME"] = L["Monochrome"], },
     set = function(i, v) self.db.profile.friendbar.text.style = v; self:UpdateSettings() end,
     get = function(i) return self.db.profile.friendbar.text.style end,
    },
    size = {
     name = L["FontSize"],
     order = 3.3,
     type = "range",
     min = 1, max = 40, step = 1,
     get = function(info) return self.db.profile.friendbar.text.size end,
     set = function(info, value) self.db.profile.friendbar.text.size = value; self:UpdateSettings(); end,
    },
    textcolor = {
     name = L["FontColor"],
     order = 3.4,
     type = "color",
     hasAlpha = true,
     get = function(info) return self.db.profile.friendbar.text.color.r, self.db.profile.friendbar.text.color.g, self.db.profile.friendbar.text.color.b, self.db.profile.friendbar.text.color.a end,
     set = function(info, r, g, b, a) self.db.profile.friendbar.text.color.r = r; self.db.profile.friendbar.text.color.g = g; self.db.profile.friendbar.text.color.b = b; self.db.profile.friendbar.text.color.a = a; self:UpdateSettings() end,
    },
    formatstring = {
     name = L["Format String"],
     order = 3.5,
     type = "input",
     width = "double",
     get = function(i) return self.db.profile.friendbar.formatstring end,
     set = function(i, v) self.db.profile.friendbar.formatstring = v; if (activeFriend ~= "") then self:UpdateFriendXP_HELPER(activeFriend) end end,
    },
    styleheader = {
     name = L["Bar Style"],
     order = 2,
     type = "header",
    },
	tile = {
		name = L["Tile"],
		desc = L["Tile the bar texture"],
		order = 2.15,
		type = "toggle",
		get = function(i) return self.db.profile.friendbar.tile end,
		set = function(i, v) self.db.profile.friendbar.tile = v self:UpdateSettings() end,
	},
    texture = {
     name = L["Bar Texture"],
     order = 2.1,
     type = "select",
     values = LSM:HashTable("statusbar"),
     dialogControl = "LSM30_Statusbar",
     get = function(info) return self.db.profile.friendbar.texture end,
     set = function(info, value) self.db.profile.friendbar.texture = value; self:UpdateSettings() end,
    },
    color = {
     name = L["Experience bar color"],
     order = 2.2,
     type = "color",
     hasAlpha = false,
     get = function(info) return self.db.profile.friendbar.color.r, self.db.profile.friendbar.color.g, self.db.profile.friendbar.color.b, self.db.profile.friendbar.color.a end,
     set = function(info, r, g, b, a) self.db.profile.friendbar.color.r = r; self.db.profile.friendbar.color.g = g; self.db.profile.friendbar.color.b = b; self.db.profile.friendbar.color.a = a; self:UpdateSettings() end,
    },
    bgcolor = {
     name = L["Experience bar background color"],
     order = 2.3,
     type = "color",
     hasAlpha = true,
     get = function(info) return self.db.profile.friendbar.bgcolor.r, self.db.profile.friendbar.bgcolor.g, self.db.profile.friendbar.bgcolor.b, self.db.profile.friendbar.bgcolor.a end,
     set = function(info, r, g, b, a) self.db.profile.friendbar.bgcolor.r = r; self.db.profile.friendbar.bgcolor.g = g; self.db.profile.friendbar.bgcolor.b = b; self.db.profile.friendbar.bgcolor.a = a; self:UpdateSettings() end,
    },
    restcolor = {
     name = L["Rest bar color"],
     order = 2.4,
     type = "color",
     hasAlpha = false,
     get = function(info) return self.db.profile.friendbar.rest.r,self.db.profile.friendbar.rest.g,self.db.profile.friendbar.rest.b,self.db.profile.friendbar.rest.a end,
     set = function(info, r, g, b, a) self.db.profile.friendbar.rest.r = r; self.db.profile.friendbar.rest.g = g; self.db.profile.friendbar.rest.b = b; self.db.profile.friendbar.rest.a = a; self:UpdateSettings() end,
    },
    locationheader = {
     name = L["Size and Position"],
     order = 1.05,
     type = "header",
    },
    width = {
     name = L["Width"],
     order = 1.1,
     type = "range",
     min = 0.01, max = 1, step = 0.01,
     get = function(info) return self.db.profile.friendbar.width end,
     set = function(info, value) self.db.profile.friendbar.width = tonumber(value);  self:UpdateSettings() end,
    },
    height = {
     name = L["Height"],
     order = 1.2,
     type = "range",
     min = 0.01, max = 60, step = 0.01,
     get = function(info) return self.db.profile.friendbar.height end,
     set = function(info,value) self.db.profile.friendbar.height = tonumber(value); self:UpdateSettings() end,
    },
    posx = {
     name = L["Horizontal Position"],
     order = 1.3,
     type = "range",
     min = 0, max = maxwidth, step = 1,
     get = function(info) return self.db.profile.friendbar.x end,
     set = function(info, value) self.db.profile.friendbar.x = tonumber(value); self:UpdateSettings() end,
    },
    posy = {
     name = L["Vertical Position"],
     order = 1.4,
     type = "range",
     min = -maxheight, max = 0, step = 1,
     get = function(info) return self.db.profile.friendbar.y end,
     set = function(info, value) self.db.profile.friendbar.y = tonumber(value); self:UpdateSettings() end,
    },
    mischeader = {
     name = L["Miscellaneous"],
     order = 4,
     type = "header",
    },
    framestrata = {
     name = L["Frame Strata"],
     order = 4.1,
     type = "select",
     style = "dropdown",
     values = { ["BACKGROUND"] = L["Background"], ["LOW"] = L["Low"], ["MEDIUM"] = L["Medium"], ["HIGH"] = L["High"], ["DIALOG"] = L["Dialog"] },
     set = function(i, v) self.db.profile.friendbar.framestrata = v; self:UpdateSettings() end,
     get = function(i) return self.db.profile.friendbar.framestrata end,
    },
    framelevel = {
     name = L["Frame Level"],
     order = 4.2,
     type = "range",
     min = 1, max = 100, step = 1,
     get = function(i) return self.db.profile.friendbar.framelevel end,
     set = function(i, v) self.db.profile.friendbar.framelevel = v; self:UpdateSettings(); end
    },

   },
  },
  tooltip = {
   name = L["LDB Tooltip"],
   type = "group",
   order = 3,
   args = {
    headerheader = {
     name = L["Header Font Style"],
     order = 1,
     type = "header",
    },
    face = {
     name = L["Font Face"],
     order = 1.1,
     type = "select",
     values = LSM:HashTable("font"),
     dialogControl = "LSM30_Font",
     get = function(info) return self.db.profile.tooltip.header.font end,
     set = function(info, value) self.db.profile.tooltip.header.font = value; self:UpdateFonts("header", self.db.profile.tooltip.header.size, self.db.profile.tooltip.header.color.r, self.db.profile.tooltip.header.color.g, self.db.profile.tooltip.header.color.g); end,
    },
    headersize = {
     name = L["Font Size"],
     order = 1.2,
     type = "range",
     min = 8, max = 24, step = 1,
     get = function(info) return self.db.profile.tooltip.header.size end,
     set = function(info, value) self.db.profile.tooltip.header.size = value; self:UpdateFonts("header", self.db.profile.tooltip.header.size, self.db.profile.tooltip.header.color.r, self.db.profile.tooltip.header.color.g, self.db.profile.tooltip.header.color.b); end,
    },
    headercolor = {
     name = L["Font Color"],
     order = 1.3,
     type = "color",
     hasAlpha = false,
     get = function(info) return self.db.profile.tooltip.header.color.r, self.db.profile.tooltip.header.color.g, self.db.profile.tooltip.header.color.b, 1 end,
     set = function(info, r, g, b) self.db.profile.tooltip.header.color.r = r; self.db.profile.tooltip.header.color.g = g; self.db.profile.tooltip.header.color.b = b; self:UpdateFonts("header", self.db.profile.tooltip.header.size, self.db.profile.tooltip.header.color.r, self.db.profile.tooltip.header.color.g, self.db.profile.tooltip.header.color.b); end,
    },
    normalheader = {
     name = L["Normal Font Style"],
     order = 2,
     type = "header",
    },
    normalface = {
     name = L["Font Face"],
     order = 2.1,
     type = "select",
     values = LSM:HashTable("font"),
     dialogControl = "LSM30_Font",
     get = function(info) return self.db.profile.tooltip.normal.font end,
     set = function(info, value) self.db.profile.tooltip.normal.font = value; self:UpdateFonts("normal", self.db.profile.tooltip.normal.size, self.db.profile.tooltip.normal.color.r, self.db.profile.tooltip.normal.color.g, self.db.profile.tooltip.normal.color.g); end,
    },
    normalsize = {
     name = L["Font Size"],
     order = 2.2,
     type = "range",
     min = 8, max = 24, step = 1,
     get = function(info) return self.db.profile.tooltip.normal.size end,
     set = function(info, value) self.db.profile.tooltip.normal.size = value; self:UpdateFonts("normal", self.db.profile.tooltip.normal.size, self.db.profile.tooltip.normal.color.r, self.db.profile.tooltip.normal.color.g, self.db.profile.tooltip.normal.color.g); end,
    },
    normalcolor = {
     name = L["Font Color"],
     type = "color",
     order = 2.3,
     hasAlpha = false,
     get = function(info) return self.db.profile.tooltip.normal.color.r, self.db.profile.tooltip.normal.color.g, self.db.profile.tooltip.normal.color.b end,
     set = function(info, r, g, b) self.db.profile.tooltip.normal.color.r = r; self.db.profile.tooltip.normal.color.g = g; self.db.profile.tooltip.normal.color.b = b; self:UpdateFonts("normal", self.db.profile.tooltip.normal.size, self.db.profile.tooltip.normal.color.r, self.db.profile.tooltip.normal.color.g, self.db.profile.tooltip.normal.color.b); end,
    },
   },
  },
  miniframe = { -- Miniframe BEGIN
   name = L["Miniframe"],
   type = "group",
   order = 2,
   args = {
    enabled = {
     name = L["Enable Miniframe"],
     order = 1,
     type = "toggle",
     set = function(i, v) self.db.profile.miniframe.enabled = v; self:SetupMiniframe() self:UpdateMiniframe() end,
     get = function(i) return self.db.profile.miniframe.enabled end,
    },
	ignoremaxlevel = {
	 name = L["Ignore Max Level"],
	 desc = L["Will not show max level players"],
	 order = 1.1,
	 type = "toggle",
	 set = function(i, v) self.db.profile.miniframe.ignoremaxlevel = v; self:RecycleAllFrames() self:UpdateMiniframe() end,
	 get = function(i) return self.db.profile.miniframe.ignoremaxlevel end,
	},
    friendlimitheader = {
     name = L["Size Limits"],
     order = 2,
     type = "header",
    },
    friendlimit = {
     name = L["Friend Limit"],
     desc = L["Maximun number of friends to show"],
     width = "half",
     order = 2.1,
     type = "input",
     get = function(i) return tostring(self.db.profile.miniframe.friendlimit) end,
     set = function(i, v) v = tonumber(v); if (v < 1) then v = 1 end self.db.profile.miniframe.friendlimit = tonumber(v); self:RecycleAllFrames() self:UpdateMiniframe() end,
    },
    columnlimit = {
     name = L["Column Limit"],
     desc = L["Number of friends to show per column"],
     width = "half",
     order = 2.2,
     type = "input",
     get = function(i) return tostring(self.db.profile.miniframe.columnlimit) end,
     set = function(i, v) self.db.profile.miniframe.columnlimit = tonumber(v); self:UpdateMiniframe() end,
    },
    locationheader = {
     name = L["Position"],
     order = 3,
     type = "header",
    },
    posx = {
     name = L["Vertical Position"],
     order = 3.1,
     type = "range",
     min = 0, max = maxwidth, step = 1,
     get = function(info) return self.db.profile.miniframe.x end,
     set = function(info, value) self.db.profile.miniframe.x = tonumber(value); self:SetupMiniframe() end,
    },
    posy = {
     name = L["Horizontal Position"],
     order = 3.2,
     type = "range",
     min = -maxheight, max = 0, step = 1,
     get = function(info) return self.db.profile.miniframe.y end,
     set = function(info, value) self.db.profile.miniframe.y = tonumber(value); self:SetupMiniframe() end,
    },
    styleheader = {
     name = L["Miniframe Style"],
     order = 4,
     type = "header",
    },
    border = {
     name = L["Miniframe Border"],
     order = 4.1,
     type = "select",
     values = LSM:HashTable("border"),
     dialogControl = "LSM30_Border",
     get = function(info) return self.db.profile.miniframe.border.border end,
     set = function(info, value) self.db.profile.miniframe.border.border = value; self:SetupMiniframe() end,
    },
	 background = {
     name = L["Miniframe Background"],
     order = 4.14,
     type = "select",
     values = LSM:HashTable("background"),
     dialogControl = "LSM30_Background",
     get = function(info) return self.db.profile.miniframe.texture end,
     set = function(info, value) self.db.profile.miniframe.texture = value; self:SetupMiniframe() end,
    },
    bordercolor = {
     name = L["Miniframe Border Color"],
     order = 4.2,
     type = "color",
     hasAlpha = true,
     get = function(info) return self.db.profile.miniframe.border.color.r, self.db.profile.miniframe.border.color.g, self.db.profile.miniframe.border.color.b, self.db.profile.miniframe.border.color.a end,
     set = function(info, r, g, b, a) self.db.profile.miniframe.border.color.r = r; self.db.profile.miniframe.border.color.g = g; self.db.profile.miniframe.border.color.b = b; self.db.profile.miniframe.border.color.a = a; self:SetupMiniframe(); end,
    },
    bordersize = {
     name = L["Border Size"],
     order = 4.3,
     type = "range",
     min = 1, max = 64, step = 1,
     get = function(i) return self.db.profile.miniframe.border.bordersize end,
     set = function(i, v) self.db.profile.miniframe.border.bordersize = v; self:SetupMiniframe() end,
    },
    insetleft = {
     name = L["Left Inset"],
     order = 4.6,
     width = "half",
     type = "input",
     get = function(i) return tostring(self.db.profile.miniframe.border.inset.left) end,
     set = function(i, v) self.db.profile.miniframe.border.inset.left = tonumber(v); self:SetupMiniframe() end,
    },
    insetright = {
     name = L["Right Inset"],
     order = 4.7,
     width = "half",
     type = "input",
     get = function(i) return tostring(self.db.profile.miniframe.border.inset.right) end,
     set = function(i, v) self.db.profile.miniframe.border.inset.right = tonumber(v); self:SetupMiniframe() end,
    },
    insettop = {
     name = L["Top Inset"],
     order = 4.8,
     width = "half",
     type = "input",
     get = function(i) return tostring(self.db.profile.miniframe.border.inset.top) end,
     set = function(i, v) self.db.profile.miniframe.border.inset.top = tonumber(v); self:SetupMiniframe() end,
    },
    insetbottom = {
     name = L["Bottom Inset"],
     order = 4.9,
     width = "half",
     type = "input",
     get = function(i) return tostring(self.db.profile.miniframe.border.inset.bottom) end,
     set = function(i, v) self.db.profile.miniframe.border.inset.bottom = tonumber(v); self:SetupMiniframe() end,
    },
    bgcolor = {
     name = L["Miniframe Background Color"],
     order = 4.5,
     type = "color",
     hasAlpha = true,
     get = function(info) return self.db.profile.miniframe.bgcolor.r, self.db.profile.miniframe.bgcolor.g, self.db.profile.miniframe.bgcolor.b, self.db.profile.miniframe.bgcolor.a end,
     set = function(info, r, g, b, a) self.db.profile.miniframe.bgcolor.r = r; self.db.profile.miniframe.bgcolor.g = g; self.db.profile.miniframe.bgcolor.b = b; self.db.profile.miniframe.bgcolor.a = a; self:SetupMiniframe() end,
    },
    xpbarheader = {
     name = L["Mini XP Bar"],
     order = 5,
     type = "header",
    },
    xpbarX = {
     name = L["XP Bar Offset X"],
     order = 5.1,
     type = "range",
     min = 0, max = maxwidth, step = 1,
     get = function(info) return self.db.profile.miniframe.xp.offsetx end,
     set = function(info, value) self.db.profile.miniframe.xp.offsetx = tonumber(value); self:UpdateMiniframe() end,
    },
    xpbarY = {
     name = L["XP Bar Offset Y"],
     order = 5.2,
     type = "range",
     min = 0, max = maxheight, step = 1,
     get = function(info) return self.db.profile.miniframe.xp.offsety end,
     set = function(info, value) self.db.profile.miniframe.xp.offsety = tonumber(value); self:UpdateMiniframe() end,
    },
    xpbarWidth = {
     name = L["XP Bar Width"],
     order = 5.3,
     type = "range",
     min = 0, max = maxwidth, step = 1,
     get = function(info) return self.db.profile.miniframe.xp.width end,
     set = function(info, value) self.db.profile.miniframe.xp.width = tonumber(value); self:SetupMiniframe(); self:UpdateMiniframe() end,
    },
    xpbarHeight = {
     name = L["XP Bar Height"],
     order = 5.4,
     type = "range",
     min = 0, max = maxheight, step = 1,
     get = function(info) return self.db.profile.miniframe.xp.height end,
     set = function(info, value) self.db.profile.miniframe.xp.height = tonumber(value); self:SetupMiniframe(); self:UpdateMiniframe() end,
    },
    xpbartexture = {
     name = L["XP Bar Texture"],
     order = 5.5,
     type = "select",
     values = LSM:HashTable("statusbar"),
     dialogControl = "LSM30_Statusbar",
     get = function(info) return self.db.profile.miniframe.xp.texture end,
     set = function(info, value) self.db.profile.miniframe.xp.texture = value; self:UpdateMiniframe() end,
    },
    xpbarbgcolor = {
     name = L["XP Bar Background Color"],
     order = 5.6,
     type = "color",
     hasAlpha = true,
     get = function(info) return self.db.profile.miniframe.xp.bgcolor.r, self.db.profile.miniframe.xp.bgcolor.g, self.db.profile.miniframe.xp.bgcolor.b, self.db.profile.miniframe.xp.bgcolor.a end,
     set = function(info, r, g, b, a) self.db.profile.miniframe.xp.bgcolor.r = r; self.db.profile.miniframe.xp.bgcolor.g = g; self.db.profile.miniframe.xp.bgcolor.b = b; self.db.profile.miniframe.xp.bgcolor.a = a; self:UpdateMiniframe() end,
    },
    xpbarrestenabled = {
     name = L["XP Bar Restbonus Enabled"],
     order = 5.7,
     type = "toggle",
     get = function(i) return self.db.profile.miniframe.rest.enabled end,
     set = function(i, v) self.db.profile.miniframe.rest.enabled = v; self:UpdateMiniframe() end
    },
	namelength = {
     name = L["Name Length"],
     desc = L["Name will be truncated to this length, 0 to disable"],
     order = 5.8,
     type = "range",
     min = 0, max = 20, step = 1,
     set = function(i, v) self.db.profile.miniframe.xp.namelen = v; self:UpdateMiniframe() end,
     get = function(i) return self.db.profile.miniframe.xp.namelen end,
    },
    xpbarrestcustom = {
     name = L["CustomRestXPBarColorToggle"],
	 desc = L["CustomRestXPBarColorToggleDesc"],
     order = 5.81,
     type = "toggle",
     get = function(i) return self.db.profile.miniframe.rest.custom end,
     set = function(i, v) self.db.profile.miniframe.rest.custom = v; self:UpdateMiniframe() end
    },
    xpbarrestcolor = {
     name = L["CustomRestXPBarColor"],
     order = 5.82,
     type = "color",
     hasAlpha = false,
     get = function(i) return self.db.profile.miniframe.rest.color.r, self.db.profile.miniframe.rest.color.g, self.db.profile.miniframe.rest.color.b end,
     set = function(i, r, g, b) self.db.profile.miniframe.rest.color.r = r; self.db.profile.miniframe.rest.color.g = g; self.db.profile.miniframe.rest.color.b = b; self:UpdateMiniframe() end,
    },
    xpbarcustom = {
	 name = L["CustomXPBarColorToggle"],
	 desc = L["CustomXPBarColorToggleDesc"],
	 order = 5.83,
	 type = "toggle",
	 get = function(i) return db.miniframe.xp.custom end,
	 set = function(i, v) db.miniframe.xp.custom = v; self:UpdateMiniframe() end,
	},
	xpbarcolor = {
	 name = L["CustomXPBarColor"],
	 order = 5.84,
	 type = "color",
	 hasAlpha = false,
	 get = function(i) return self.db.profile.miniframe.xp.color.r, self.db.profile.miniframe.xp.color.g, self.db.profile.miniframe.xp.color.b end,
	 set = function(i, r, g, b) self.db.profile.miniframe.xp.color.r = r; self.db.profile.miniframe.xp.color.g = g; self.db.profile.miniframe.xp.color.b = b; self:UpdateMiniframe() end
	},
    face = {
     name = L["Font Face"],
     order = 5.910,
     type = "select",
     values = LSM:HashTable("font"),
     dialogControl = "LSM30_Font",
     get = function(info) return self.db.profile.miniframe.xp.text.font end,
     set = function(info, value) self.db.profile.miniframe.xp.text.font = value; self:UpdateMiniframe() end,
    },
    style = {
     name = L["Font Style"],
     order = 5.911,
     type = "select",
     style = "dropdown",
     values = { [""] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick Outline", ["MONOCHROME"] = "Monochrome", },
     set = function(i, v) self.db.profile.miniframe.xp.text.style = v; self:UpdateMiniframe() end,
     get = function(i) return self.db.profile.miniframe.xp.text.style end,
    },
    size = {
     name = L["Font Size"],
     order = 5.912,
     type = "range",
     min = 1, max = 40, step = 1,
     get = function(info) return self.db.profile.miniframe.xp.text.size end,
     set = function(info, value) self.db.profile.miniframe.xp.text.size = value; self:UpdateMiniframe(); end,
    },
    textcolor = {
     name = L["Font Color"],
     order = 5.913,
     type = "color",
     hasAlpha = true,
     get = function(info) return self.db.profile.miniframe.xp.text.color.r, self.db.profile.miniframe.xp.text.color.g, self.db.profile.miniframe.xp.text.color.b, self.db.profile.miniframe.xp.text.color.a end,
     set = function(info, r, g, b, a) self.db.profile.miniframe.xp.text.color.r = r; self.db.profile.miniframe.xp.text.color.g = g; self.db.profile.miniframe.xp.text.color.b = b; self.db.profile.miniframe.xp.text.color.a = a; self:UpdateMiniframe() end,
    },
    formatstring = {
     name = L["Format String"],
     desc = L["Changes the text that is displayed"],
     order = 5.914,
     type = "input",
     width = "double",
     get = function(i) return self.db.profile.miniframe.formatstring end,
     set = function(i, v) self.db.profile.miniframe.formatstring = v; self:UpdateMiniframe() end,
    },
    flashoutgoingheader = {
     name = L["Comm - Outgoing Indicator"],
     order = 6,
     type = "header",
    },
    oenabled = {
     name = L["Enabled"],
     order = 6.1,
     type = "toggle",
     get = function(i) return self.db.profile.miniframe.outgoing.enabled end,
     set = function(i, v) self.db.profile.miniframe.outgoing.enabled = v end,
    },
    flash = {
     name = L["Texture"],
     order = 6.2,
     type = "select",
     values = LSM:HashTable("background"),
     dialogControl = "LSM30_Background",
     get = function(info) return self.db.profile.miniframe.outgoing.texture end,
     set = function(info, value) self.db.profile.miniframe.outgoing.texture = value; self:SetupMiniframe() end,
    },
    opoint = {
     name = L["Point"],
     order = 6.3,
     type = "select",
     style = "dropdown",
     values = { ["TOP"] = L["Top"], ["RIGHT"] = L["Right"], ["BOTTOM"] = L["Bottom"], ["LEFT"] = L["Left"], ["CENTER"] = L["Center"], ["TOPRIGHT"] = L["Top-Right"], ["TOPLEFT"] = L["Top-Left"], ["BOTTOMRIGHT"] = L["Bottom-Right"], ["BOTTOMLEFT"] = L["Bottom-Left"] },
     get = function(i) return self.db.profile.miniframe.outgoing.point end,
     set = function(i, v) self.db.profile.miniframe.outgoing.point = v; self:SetupMiniframe() end,
    },
    orelativepoint = {
     name = L["Relative Point"],
     order = 6.4,
     type = "select",
     style = "dropdown",
     values = { ["TOP"] = L["Top"], ["RIGHT"] = L["Right"], ["BOTTOM"] = L["Bottom"], ["LEFT"] = L["Left"], ["CENTER"] = L["Center"], ["TOPRIGHT"] = L["Top-Right"], ["TOPLEFT"] = L["Top-Left"], ["BOTTOMRIGHT"] = L["Bottom-Right"], ["BOTTOMLEFT"] = L["Bottom-Left"] },
     get = function(i) return self.db.profile.miniframe.outgoing.relativePoint end,
     set = function(i, v) self.db.profile.miniframe.outgoing.relativePoint = v; self:SetupMiniframe() end,
    },
    flashposx = {
     name = L["Vertical Position"],
     order = 6.5,
     type = "range",
     min = -600, max = 600, step = 1,
     get = function(info) return self.db.profile.miniframe.outgoing.x end,
     set = function(info, value) self.db.profile.miniframe.outgoing.x = value; self:SetupMiniframe() end,
    },
    flashposy = {
     name = L["Horizontal Position"],
     order = 6.6,
     type = "range",
     min = -600, max = 600, step = 1,
     get = function(info) return self.db.profile.miniframe.outgoing.y end,
     set = function(info, value) self.db.profile.miniframe.outgoing.y = value; self:SetupMiniframe() end,
    },
    flashheight = {
     name = L["Height"],
     order = 6.7,
     type = "range",
     min = 8, max = 100, step = 1,
     get = function(info) return self.db.profile.miniframe.outgoing.height end,
     set = function(info, value) self.db.profile.miniframe.outgoing.height = tonumber(value); self:SetupMiniframe() end,
    },
    flashwidth = {
     name = L["Width"],
     order = 6.8,
     type = "range",
     min = 8, max = 100, step = 1,
     get = function(info) return self.db.profile.miniframe.outgoing.width end,
     set = function(info, value) self.db.profile.miniframe.outgoing.width = tonumber(value); self:SetupMiniframe() end,
    },
    flashincomingheader = {
     name = L["Comm - Incoming Indicator"],
     order = 7,
     type = "header",
    },
    ienabled = {
     name = L["Enabled"],
     order = 7.1,
     type = "toggle",
     get = function(i) return self.db.profile.miniframe.incoming.enabled end,
     set = function(i, v) self.db.profile.miniframe.incoming.enabled = v end,
    },
    iflash = {
     name = L["Texture"],
     order = 7.2,
     type = "select",
     values = LSM:HashTable("background"),
     dialogControl = "LSM30_Background",
     get = function(info) return self.db.profile.miniframe.incoming.texture end,
     set = function(info, value) self.db.profile.miniframe.incoming.texture = value; self:SetupMiniframe() end,
    },
    ipoint = {
      name = L["Point"],
      order = 7.3,
      type = "select",
      style = "dropdown",
      values = { ["TOP"] = L["Top"], ["RIGHT"] = L["Right"], ["BOTTOM"] = L["Bottom"], ["LEFT"] = L["Left"], ["CENTER"] = L["Center"], ["TOPRIGHT"] = L["Top-Right"], ["TOPLEFT"] = L["Top-Left"], ["BOTTOMRIGHT"] = L["Bottom-Right"], ["BOTTOMLEFT"] = L["Bottom-Left"] },
      get = function(i) return self.db.profile.miniframe.incoming.point end,
      set = function(i, v) self.db.profile.miniframe.incoming.point = v; self:SetupMiniframe() end,
     },
     irelativepoint = {
      name = L["Relative Point"],
      order = 7.4,
      type = "select",
      style = "dropdown",
      values = { ["TOP"] = L["Top"], ["RIGHT"] = L["Right"], ["BOTTOM"] = L["Bottom"], ["LEFT"] = L["Left"], ["CENTER"] = L["Center"], ["TOPRIGHT"] = L["Top-Right"], ["TOPLEFT"] = L["Top-Left"], ["BOTTOMRIGHT"] = L["Bottom-Right"], ["BOTTOMLEFT"] = L["Bottom-Left"] },
      get = function(i) return self.db.profile.miniframe.incoming.relativePoint end,
      set = function(i, v) self.db.profile.miniframe.incoming.relativePoint = v; self:SetupMiniframe() end,
     },
    iflashposx = {
     name = L["Vertical Position"],
     order = 7.5,
     type = "range",
     min = -600, max = 600, step = 1,
     get = function(info) return self.db.profile.miniframe.incoming.x end,
     set = function(info, value) self.db.profile.miniframe.incoming.x = tonumber(value); self:SetupMiniframe() end,
    },
    iflashposy = {
     name = L["Horizontal Position"],
     order = 7.6,
     type = "range",
     min = -600, max = 600, step = 1,
     get = function(info) return self.db.profile.miniframe.incoming.y end,
     set = function(info, value) self.db.profile.miniframe.incoming.y = value; self:SetupMiniframe() end,
    },
    iflashheight = {
     name = L["Height"],
     order = 7.7,
     type = "range",
     min = 8, max = 100, step = 1,
     get = function(info) return self.db.profile.miniframe.incoming.height end,
     set = function(info, value) self.db.profile.miniframe.incoming.height = value; self:SetupMiniframe() end,
    },
    iflashwidth = {
     name = L["Width"],
     order = 7.8,
     type = "range",
     min = 8, max = 100, step = 1,
     get = function(info) return self.db.profile.miniframe.incoming.width end,
     set = function(info, value) self.db.profile.miniframe.incoming.width = tonumber(value); self:SetupMiniframe() end,
    },
    mischeader = {
     name = L["Miscellaneous"],
     order = 8,
     type = "header",
    },
    framestrata = {
     name = L["Frame Strata"],
     order = 8.1,
     type = "select",
     style = "dropdown",
     values = { ["BACKGROUND"] = L["Background"], ["LOW"] = L["Low"], ["MEDIUM"] = L["Medium"], ["HIGH"] = L["High"], ["DIALOG"] = L["Dialog"] },
     set = function(i, v) self.db.profile.miniframe.framestrata = v; self:SetupMiniframe() end,
     get = function(i) return self.db.profile.miniframe.framestrata end,
    },
    framelevel = {
     name = L["Frame Level"],
     order = 8.2,
     type = "range",
     min = 1, max = 100, step = 1,
     get = function(i) return self.db.profile.miniframe.framelevel end,
     set = function(i, v) self.db.profile.miniframe.framelevel = v; self:SetupMiniframe(); end
    },
   },
  },
  pf = { -- PlayerFrame BEGIN
   name = L["Player XP Frame"],
   order = 4.1,
   type = "group",
   args = {
    enabled = {
     name = L["Enabled"],
     order = 1,
     type = "toggle",
     set = function(i, v) self.db.profile.pf.enabled = v; self:SendXP() end,
     get = function(i) return self.db.profile.pf.enabled end,
    },
    tooltip = {
     name = L["Tooltip"],
     type = "toggle",
     get = function(i) return self.db.profile.pf.tooltip end,
     set = function(i, v) self.db.profile.pf.tooltip = v end,
    },
    formatstring = {
     name = L["Format String"],
	 desc = L["Changes the text that is displayed"],
     order = 2,
     type = "input",
     width = "double",
     get = function(i) return self.db.profile.pf.formatstring end,
     set = function(i, v) self.db.profile.pf.formatstring = v; self:SendXP() end,
    },
    texture = {
     name = L["Bar Texture"],
     order = 3,
     type = "select",
     values = LSM:HashTable("statusbar"),
     dialogControl = "LSM30_Statusbar",
     get = function(i) return self.db.profile.pf.texture end,
     set = function(i, v) self.db.profile.pf.texture = v; self:UpdateSettings() end,
    },
	--[[alpha = {
	 name = "Alpha",
	 desc = "Alpha of the experience bar",
	 order = 3.1,
	 type = "range",
	 min = 0, max = 1, inc = 0.1,
	 get = function(i) return self.db.profile.pf.alpha end,
	 set = function(i, v) self.db.profile.pf.alpha = v; self:UpdateSettings() end,
	}, ]]--
    color = {
     name = L["Experience bar color"],
     order = 2.2,
     type = "color",
     hasAlpha = false,
     get = function(info) return self.db.profile.pf.color.r, self.db.profile.pf.color.g, self.db.profile.pf.color.b end,
     set = function(info, r, g, b) self.db.profile.pf.color.r = r; self.db.profile.pf.color.g = g; self.db.profile.pf.color.b = b; self:UpdateSettings() end,
    },
    bgcolor = {
     name = L["Experience bar background color"],
     order = 2.3,
     type = "color",
     hasAlpha = true,
     get = function(info) return self.db.profile.pf.bgcolor.r, self.db.profile.pf.bgcolor.g, self.db.profile.pf.bgcolor.b, self.db.profile.pf.bgcolor.a end,
     set = function(info, r, g, b, a) self.db.profile.pf.bgcolor.r = r; self.db.profile.pf.bgcolor.g = g; self.db.profile.pf.bgcolor.b = b; self.db.profile.pf.bgcolor.a = a; self:UpdateSettings() end,
    },
    restcolor = {
     name = L["Rest bar color"],
     order = 2.4,
     type = "color",
     hasAlpha = false,
     get = function(info) return self.db.profile.pf.rest.r, self.db.profile.pf.rest.g, self.db.profile.pf.rest.b end,
     set = function(info, r, g, b) self.db.profile.pf.rest.r = r; self.db.profile.pf.rest.g = g; self.db.profile.pf.rest.b = b; self:UpdateSettings() end,
    },
   },
  }, -- PlayerFrame END
  partyframes = { -- PartyFrames BEGIN
   name = L["Party XP Frames"],
   order = 4.2,
   type = "group",
   args = {
    tooltip = {
     name = L["Tooltip"],
     type = "toggle",
     get = function(i) return self.db.profile.partyframes.tooltip end,
     set = function(i, v) self.db.profile.partyframes.tooltip = v end,
    },
    texture = {
     name = L["Bar Texture"],
     order = 3,
     type = "select",
     values = LSM:HashTable("statusbar"),
     dialogControl = "LSM30_Statusbar",
     get = function(i) return self.db.profile.partyframes.texture end,
     set = function(i, v) self.db.profile.partyframes.texture = v; self:HookBlizzPartyFrames() end,
    },
    restcolor = {
     name = L["Rest bar color"],
     order = 2.4,
     type = "color",
     hasAlpha = false,
     get = function(info) return self.db.profile.partyframes.rested.r, self.db.profile.partyframes.rested.g, self.db.profile.partyframes.rested.b end,
     set = function(info, r, g, b) self.db.profile.partyframes.rested.r = r; self.db.profile.partyframes.rested.g = g; self.db.profile.partyframes.rested.b = b; self:HookBlizzPartyFrames() end,
    },
    xpcolor = {
     name = L["Experience bar color"],
     order = 2.2,
     type = "color",
     hasAlpha = false,
     get = function(info) return self.db.profile.partyframes.xp.r, self.db.profile.partyframes.xp.g, self.db.profile.partyframes.xp.b end,
     set = function(info, r, g, b) self.db.profile.partyframes.xp.r = r; self.db.profile.partyframes.xp.g = g; self.db.profile.partyframes.xp.b = b; self:HookBlizzPartyFrames() end,
    },
   },
  }, -- PartyFrames END
 },
}


 options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
 return options
end

function FriendXP:FriendKey(mode,friend)
 if (mode == "get") then
  local realmname = GetRealmName()
  local key = realmname .. "-" .. friend;
  self:Debug("Player key " .. key);
  return key
 end

 if (mode == "splode") then
  local mid = string.find(friend, "-", 1, true)
  if (mid == nil) then
   return nil
  end
  local realm = string.sub(friend,  1, mid - 1)
  local friend = string.sub(friend, mid + 1, -1)
  return realm, friend
 end
end

function FriendXP:CreateFriendXPBar() -- Should merge its update functions here aswell like SetupMiniframe
 if (xpbar) then return end
 xpbar = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate")
 xpbar.bg = xpbar:CreateTexture(nil, 'BACKGROUND')
 xpbar.rest = CreateFrame('StatusBar', nil, xpbar, BackdropTemplateMixin and "BackdropTemplate")
 xpbar.xp = CreateFrame('StatusBar', nil, xpbar.rest, BackdropTemplateMixin and "BackdropTemplate")

 xpbar:SetFrameStrata(self.db.profile.friendbar.framestrata)
 xpbar:SetFrameLevel(self.db.profile.friendbar.framelevel)

 xpbar.bg:SetAllPoints(true)
 xpbar.xp:SetAllPoints(true)
 xpbar.rest:SetAllPoints(true)

 xpbar.text = xpbar.xp:CreateFontString(nil, 'OVERLAY')
 xpbar.text:SetFont(LSM:Fetch("font", self.db.profile.friendbar.text.font), self.db.profile.friendbar.text.size, self.db.profile.friendbar.text.style, "")
 xpbar.text:SetPoint("CENTER")

 xpbar.bg:SetTexture(LSM:Fetch("statusbar", self.db.profile.friendbar.texture))
 xpbar.rest:SetStatusBarTexture(LSM:Fetch("statusbar", self.db.profile.friendbar.texture))
 xpbar.xp:SetStatusBarTexture(LSM:Fetch("statusbar", self.db.profile.friendbar.texture))

 xpbar.bg:SetVertexColor(self.db.profile.friendbar.bgcolor.r, self.db.profile.friendbar.bgcolor.g, self.db.profile.friendbar.bgcolor.b, self.db.profile.friendbar.bgcolor.a)
 xpbar.xp:SetStatusBarColor(self.db.profile.friendbar.color.r, self.db.profile.friendbar.color.g, self.db.profile.friendbar.color.b)
 xpbar.rest:SetStatusBarColor(self.db.profile.friendbar.rest.r, self.db.profile.friendbar.rest.g, self.db.profile.friendbar.rest.b)

 xpbar.xp:SetMinMaxValues(0, 1000)
 xpbar.xp:SetValue(0)
 xpbar.xp:GetStatusBarTexture():SetHorizTile(self.db.profile.friendbar.tile)
 xpbar.rest:SetMinMaxValues(0, 1000)
 xpbar.rest:SetValue(0)

 -- For moving
 xpbar.move = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate")
 xpbar.move:SetBackdrop({bgFile = LSM:Fetch("background", "Solid")})
 xpbar.move:SetBackdropColor(1,0,0,0.75)
 xpbar.move:SetAllPoints(true)
 xpbar.move:Hide()

 xpbar:Hide()
end

function FriendXP:UpdateSettings()
 xpbar:ClearAllPoints()
 xpbar:SetFrameStrata(self.db.profile.friendbar.framestrata)
 xpbar:SetFrameLevel(self.db.profile.friendbar.framelevel)
 xpbar:SetPoint("TOPLEFT", UIParent, self.db.profile.friendbar.x, self.db.profile.friendbar.y)
 xpbar:SetHeight(self.db.profile.friendbar.height)
 xpbar:SetWidth(UIParent:GetWidth() * self.db.profile.friendbar.width)

 xpbar.bg:SetTexture(LSM:Fetch("statusbar", self.db.profile.friendbar.texture), self.db.profile.friendbar.tile)
 xpbar.rest:SetStatusBarTexture(LSM:Fetch("statusbar", self.db.profile.friendbar.texture))
 xpbar.xp:SetStatusBarTexture(LSM:Fetch("statusbar", self.db.profile.friendbar.texture))

 xpbar.bg:SetVertexColor(self.db.profile.friendbar.bgcolor.r, self.db.profile.friendbar.bgcolor.g, self.db.profile.friendbar.bgcolor.b, self.db.profile.friendbar.bgcolor.a)
 xpbar.xp:SetStatusBarColor(self.db.profile.friendbar.color.r, self.db.profile.friendbar.color.g, self.db.profile.friendbar.color.b)
 xpbar.rest:SetStatusBarColor(self.db.profile.friendbar.rest.r, self.db.profile.friendbar.rest.g, self.db.profile.friendbar.rest.b)

 -- Not sure what this is for
 --if xpbar.xp:GetStatusBarTexture().SetHorizTile then
 --xpbar.xp:GetStatusBarTexture():SetHorizTile(false)
 --end
 --if xpbar.rest:GetStatusBarTexture().SetHorizTile then
  --xpbar.rest:GetStatusBarTexture():SetHorizTile(false)
 --end

 xpbar.xp:GetStatusBarTexture():SetHorizTile(self.db.profile.friendbar.tile)
 xpbar.rest:GetStatusBarTexture():SetHorizTile(self.db.profile.friendbar.tile)

 xpbar.text:SetFont(LSM:Fetch("font", self.db.profile.friendbar.text.font), self.db.profile.friendbar.text.size, self.db.profile.friendbar.text.style, "")
 xpbar.text:SetTextColor(self.db.profile.friendbar.text.color.r, self.db.profile.friendbar.text.color.g, self.db.profile.friendbar.text.color.b, self.db.profile.friendbar.text.color.a);

 if (self.db.profile.enabled and self.db.profile.friendbar.enabled) then
  xpbar:Show()
 else
  xpbar:Hide()
 end
 
 if (self.playerxp) then
  self.playerxp.rest:SetStatusBarTexture(LSM:Fetch("statusbar", self.db.profile.pf.texture))
  self.playerxp.xp:SetStatusBarTexture(LSM:Fetch("statusbar", self.db.profile.pf.texture))
  self.playerxp.rest:SetStatusBarColor(self.db.profile.pf.rest.r, self.db.profile.pf.rest.g, self.db.profile.pf.rest.b)
  self.playerxp.xp:SetStatusBarColor(self.db.profile.pf.color.r, self.db.profile.pf.color.g, self.db.profile.pf.color.b)
  
  self.playerxp:SetBackdrop({bgFile = LSM:Fetch("statusbar", self.db.profile.pf.texture)})
  self.playerxp:SetBackdropColor(self.db.profile.pf.bgcolor.r, self.db.profile.pf.bgcolor.g, self.db.profile.pf.bgcolor.b, self.db.profile.pf.bgcolor.a)
 end
end

-- Returns friend table, really need to redo the activeFriends table to avoid all this looping (DONE)
function FriendXP:FetchFriend(friend)
 if (friends[friend]) then
  return friends[friend]
 end
end

function FriendXP:UpdateFriendXP_HELPER(friend)
 self:UpdateFriendXP(self:FetchFriend(friend))
end

function FriendXP:UpdateFriendXP(ft) -- Friendbar
 -- Need to modify function to only need friend name/index to show friend
 -- May also need to work on the activeFriends table to make that easier
 -- like -- function FriendXP:UpdateFriendXP(id)
 if (self.db.profile.friendbar.enabled and self.db.profile.enabled) then
  xpbar:Show()
 else
  xpbar:Hide()
  return
 end

 if (ft == nil) then return end

 xpbar.xp:SetMinMaxValues(0, ft["totalxp"])
 xpbar.xp:SetValue(ft["xp"])
 xpbar.rest:SetMinMaxValues(0, ft["totalxp"])

 local isDisabled = "";
 if (ft["xpdisabled"] == 1) then
  isDisabled = L["XPGainsDisabled"]
 end

 if (ft["restbonus"] and ft["restbonus"] > 0) then
  xpbar.rest:SetValue(ft["xp"] + ft["restbonus"])
 else
  xpbar.rest:SetValue(0)
 end
 xpbar.text:SetText(self:FormatString(self.db.profile.friendbar.formatstring, ft))
end

function FriendXP:FormatString(string, ft)
 self:Debug("Format String: " .. string)
 local pname = ft["name"]
 if (self.db.profile.miniframe.xp.namelen > 0) then
  pname = strsub(ft["name"], 0, self.db.profile.miniframe.xp.namelen)
 end
 string = gsub(string, "%%n", pname)
 string = gsub(string, "%%l", tostring(ft["level"]))
 string = gsub(string, "%%xp", tostring(ft["xp"]))
 string = gsub(string, "%%txp", tostring(ft["totalxp"]))
 string = gsub(string, "%%p(%d?)", function(digits) if digits ~= "" then return self:Round((ft["xp"]/ft["totalxp"])*100, tonumber(digits)) else return floor((ft["xp"]/ft["totalxp"])*100) end end)
 string = gsub(string, "%%rm", ft["totalxp"] - ft["xp"])

 if (ft["restbonus"] > 0) then
  string = gsub(string, "(%%rs)(.-)(%%re)", "%2")
  string = gsub(string, "%%r", tostring(ft["restbonus"]))
 else
  string = gsub(string, "%%rs.-%%re", "")
 end
 if (ft["xpdisabled"] == 1) then
  string = gsub(string, "%%d", L["XPGainsDisabled"])
 else
  string = gsub(string, "%%d", "")
 end

 return string
end

function FriendXP:FlashFrame(frame, elapsed)
	local alpha = frame:GetAlpha()
	if (not frame.startTime) then frame.startTime = GetTime() end
	if (frame.direction == nil) then frame.direction = 0 end
 
	if (frame.direction == 0) then
		alpha = GetTime() - frame.startTime -- Fade in over a second
		if alpha < 0.01 then alpha = 0.01 end -- GetTime() - startTime is 0 for a wee bit so this stop the part below from just hiding the frame immediately
		if (alpha > 1) then
			alpha = 1
			frame.direction = 1
		end
	else
		alpha = (frame.startTime + 2.0 - GetTime()) -- Fade out over a second
		if (alpha <= 0) then
			alpha = 0
			frame.direction = 0
		end
	end

	frame:SetAlpha(alpha)

	if (frame:GetAlpha() <= 0) then
		frame.startTime = nil
		frame.direction = nil
		frame:SetAlpha(0)
		frame:Hide()
	end
end

function FriendXP:SetupMiniframe()
 if (Miniframe == nil) then
  Miniframe = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate")
  Miniframe:SetBackdrop({bgFile = LSM:Fetch("background", self.db.profile.miniframe.texture), edgeFile = LSM:Fetch("border", self.db.profile.miniframe.border.border), tile = false, tileSize = 0, edgeSize = self.db.profile.miniframe.border.bordersize, insets = { left = self.db.profile.miniframe.border.inset.left, right = self.db.profile.miniframe.border.inset.right, top = self.db.profile.miniframe.border.inset.top, bottom = self.db.profile.miniframe.border.inset.bottom }})
  Miniframe.flash = CreateFrame("Frame", nil, Miniframe, BackdropTemplateMixin and "BackdropTemplate")
  Miniframe.flash:Hide()
  Miniframe.incoming = CreateFrame("Frame", nil, Miniframe, BackdropTemplateMixin and "BackdropTemplate")
  Miniframe.incoming:Hide()
  --Miniframe.flash:SetScript("OnUpdate", function(self) local alpha = self:GetAlpha(); alpha = alpha - 0.03; if (alpha < 0) then alpha = 0; end; self:SetAlpha(alpha); if (self:GetAlpha() <= 0) then self:SetAlpha(1); self:Hide(); end; end)
  Miniframe.flash:SetScript("OnUpdate", function(self, elapsed) FriendXP:FlashFrame(self, elapsed) end)
  Miniframe.incoming:SetScript("OnUpdate", function(self, elapsed) FriendXP:FlashFrame(self, elapsed) end)

 -- For moving
  Miniframe.move = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate")
  Miniframe.move:SetBackdrop({bgFile = LSM:Fetch("background", "Solid")})
  Miniframe.move:SetBackdropColor(1,0,0,0.75)
  Miniframe.move:SetAllPoints(Miniframe)
  Miniframe.move:Hide()
 end

 if (self.db.profile.miniframe.enabled == true and self.db.profile.enabled) then
  Miniframe:Show()
 else
  Miniframe:Hide()
 end

 Miniframe.flash:SetBackdrop({bgFile = LSM:Fetch("background", self.db.profile.miniframe.outgoing.texture), tile = false, tileSize = 0, })
 Miniframe.flash:ClearAllPoints()
 Miniframe.flash:SetPoint(self.db.profile.miniframe.outgoing.point, Miniframe, self.db.profile.miniframe.outgoing.relativePoint, self.db.profile.miniframe.outgoing.x, self.db.profile.miniframe.outgoing.y)
 Miniframe.flash:SetWidth(self.db.profile.miniframe.outgoing.width);
 Miniframe.flash:SetHeight(self.db.profile.miniframe.outgoing.height);

 Miniframe.incoming:SetBackdrop({bgFile = LSM:Fetch("background", self.db.profile.miniframe.incoming.texture), tile = false, tileSize = 0, })
 Miniframe.incoming:ClearAllPoints()
 Miniframe.incoming:SetPoint(self.db.profile.miniframe.incoming.point, Miniframe, self.db.profile.miniframe.incoming.relativePoint, self.db.profile.miniframe.incoming.x, self.db.profile.miniframe.incoming.y)
 Miniframe.incoming:SetWidth(self.db.profile.miniframe.incoming.width);
 Miniframe.incoming:SetHeight(self.db.profile.miniframe.incoming.height);


 Miniframe:ClearAllPoints()
 Miniframe:SetFrameStrata(self.db.profile.miniframe.framestrata)
 Miniframe:SetFrameLevel(self.db.profile.miniframe.framelevel)
 Miniframe:SetPoint("TOPLEFT", UIParent, "TOPLEFT", self.db.profile.miniframe.x, self.db.profile.miniframe.y);

 Miniframe:SetBackdrop({bgFile = LSM:Fetch("background", self.db.profile.miniframe.texture), edgeFile = LSM:Fetch("border", self.db.profile.miniframe.border.border), tile = false, tileSize = 0, edgeSize = self.db.profile.miniframe.border.bordersize, insets = { left = self.db.profile.miniframe.border.inset.left, right = self.db.profile.miniframe.border.inset.right, top = self.db.profile.miniframe.border.inset.top, bottom = self.db.profile.miniframe.border.inset.bottom }})
 Miniframe:SetBackdropColor(self.db.profile.miniframe.bgcolor.r, self.db.profile.miniframe.bgcolor.g, self.db.profile.miniframe.bgcolor.b, self.db.profile.miniframe.bgcolor.a)
 Miniframe:SetBackdropBorderColor(self.db.profile.miniframe.border.color.r, self.db.profile.miniframe.border.color.g, self.db.profile.miniframe.border.color.b, self.db.profile.miniframe.border.color.a)
end

local miniframes = { } -- Holds frame refs
function FriendXP:UpdateMiniframe()
 if (not Miniframe) then self:Debug("MINIFRAME UNDEFINED") return end

 if (self.db.profile.miniframe.enabled and self.db.profile.enabled) then
  Miniframe:Show()
 else
  Miniframe:Hide()
  self:RecycleAllFrames()
  return
 end

 local b = 0 -- Column Counter
 local x = 0 -- Counter for frame position in column goes 0 to columnlimit - 1, then increments b and resets to 0
 local y = 0 -- A counter for each frame

 local player = UnitName("player")

 self:RemoveOutdated()
 --self:RecycleAllFrames()
 
 local MAXLEVEL = GetMaxPlayerLevel() -- Maybe move somewhere else, doesn't need to be called often
 
 if (friends[player] ~= nil and not (self.db.profile.miniframe.ignoremaxlevel and friends[player]["level"] == MAXLEVEL)) then -- Ensure that the player is always the first
  self:CreateMinibar(friends[player], b, y, x)
  x = x + 1
  y = y + 1
 else
  self:Debug("PLAYER DATA WAS NIL or max level")
 end

 for key, value in pairs(friends) do
  local ft = friends[key]
  -- GetLevelByPlayer(name) Add code so that if player was one level below and recently leveled, we will show them for a bit and then remove them
  -- right now when going from 109 to 110, friend is then ignored and left at 109 until removed due to inactivity
  -- allowing it to go to 110, even briefly, will cause it to be removed properly instead of hanging around
  if (not (self.db.profile.miniframe.ignoremaxlevel and ft["level"] == MAXLEVEL) and y < self.db.profile.miniframe.friendlimit) then 
   if (ft["name"] ~= player) then -- Ignore player
    if (x >= self.db.profile.miniframe.columnlimit) then
     x = 0;
     b = b + 1;
    end
   
    self:CreateMinibar(ft, b, y, x)
    x = x + 1
    y = y + 1
   end
  else
   self:Debug("Removing max level from miniframe")
   self:RecycleFrame(key)
  end

  -- Needs more work
  if (b == 0) then
   -- Componenets of height:
   -- Height of each statusbar + the 2px buffer i give it
   -- Buffer around top and bottom in the form off xp.offset.y
   -- the +2 at the end is just for a little more wiggle room
   -- added the + height at the beginning to account for the button
   Miniframe:SetHeight((self.db.profile.miniframe.xp.offsety * 2) + ((self.db.profile.miniframe.xp.height + 2) * x) + 2)
   Miniframe:SetWidth(self.db.profile.miniframe.xp.height + self.db.profile.miniframe.xp.width + (self.db.profile.miniframe.xp.offsetx * 2))
   --Miniframe:Show()
  else
   Miniframe:SetHeight((self.db.profile.miniframe.xp.offsety * 2) + ((self.db.profile.miniframe.xp.height + 2) * (self.db.profile.miniframe.columnlimit)) + 2)
   Miniframe:SetWidth((self.db.profile.miniframe.xp.height*(b+1)) + (self.db.profile.miniframe.xp.width * (b + 1)) + (self.db.profile.miniframe.xp.offsetx * 2) + (4 * b))
   --Miniframe:Show()
  end
  end
  if (y == 0) then -- Player and friends are all max level and set to be hidden, don't show miniframe FIX ME
   Miniframe:Hide()
  end
end

function FriendXP:CreateMinibar(ft, b, y, x) -- This whole function needs work
 if (not ft) then return end -- FIXME
 --self:Print("Creating minibar: ", b, y, x)

 local db = self.db.profile.miniframe -- Shorten some repetitive stuff

 local class = strupper(ft["class"]);
 if (not class) then
  class = "MAGE";
 end
 --["name"],ft["level"],ft["xp"] .. "/" .. ft["totalxp"],ft["restbonus"],)
 local frame = self:GetFrame(ft["name"]);
 frame:SetPoint("TOPLEFT", Miniframe, "TOPLEFT", db.xp.offsetx + ((db.xp.width) * b) + (4*b) + (db.xp.height * (b+1)), (-(db.xp.height+2) * x)-db.xp.offsety - 2)
 frame:SetWidth(db.xp.width);
 frame:SetHeight(db.xp.height);
 frame:SetMinMaxValues(0, ft["totalxp"])
 --frame.xp:ClearAllPoints()
 --frame.xp:SetAllPoints(true)
 frame.xp:SetMinMaxValues(0, ft["totalxp"])


 if (ft["level"] == ft["maxlevel"]) then
  frame.xp:SetValue(ft["totalxp"])
 else
  frame.xp:SetValue(ft["xp"])
 end
 if (db.rest.enabled) then
  if (ft["restbonus"] + ft["xp"] > ft["totalxp"]) then
   frame:SetValue(ft["totalxp"])
  else
   frame:SetValue(ft["restbonus"] + ft["xp"])
  end
 else
  frame:SetValue(0)
 end
 frame:SetStatusBarTexture(LSM:Fetch("statusbar", db.xp.texture))
  --frame:SetStatusBarColor(self.db.profile.miniframe.rest.color.r, self.db.profile.miniframe.rest.color.g, self.db.profile.miniframe.rest.color.b)
 if (db.rest.custom) then
  frame:SetStatusBarColor(db.rest.color.r, db.rest.color.g, db.rest.color.b)
 else
  frame:SetStatusBarColor(RAID_CLASS_COLORS[class]["r"] - 0.2, RAID_CLASS_COLORS[class]["g"] - 0.2, RAID_CLASS_COLORS[class]["b"] - 0.2)
 end
 frame:Show()

 frame.xp:SetStatusBarTexture(LSM:Fetch("statusbar", db.xp.texture))
 if (db.xp.custom) then
  frame.xp:SetStatusBarColor(db.xp.color.r, db.xp.color.g, db.xp.color.b)
 else
  frame.xp:SetStatusBarColor(RAID_CLASS_COLORS[class]["r"], RAID_CLASS_COLORS[class]["g"], RAID_CLASS_COLORS[class]["b"])
 end
 frame.bg:ClearAllPoints()
 frame.bg:SetAllPoints(true)
 frame.bg:SetTexture(LSM:Fetch("statusbar", db.xp.texture))
 frame.bg:SetVertexColor(db.xp.bgcolor.r, db.xp.bgcolor.g, db.xp.bgcolor.b, db.xp.bgcolor.a)
 frame.text:SetFont(LSM:Fetch("font", db.xp.text.font), db.xp.text.size, db.xp.text.style, "")
 frame.text:SetTextColor(db.xp.text.color.r, db.xp.text.color.g, db.xp.text.color.b, db.xp.text.color.a);
 local pname = ft["name"];
 if (db.xp.namelen > 0) then
  pname = strsub(ft["name"], 0, db.xp.namelen)
 end
 frame.text:SetPoint("LEFT")
 frame.text:SetText(self:FormatString(db.formatstring, ft))
  --frame.text:SetFormattedText("%d:%s", ft["level"], pname)

 -- Tooltip
 frame:SetScript("OnEnter", function() self:MiniTooltip(frame, true, ft) end)
 frame:SetScript("OnLeave", function() self:MiniTooltip(frame, false) end)

 -- Configure the button
 local buttonBg = "Interface/BUTTONS/UI-CheckBox-Check-Disabled.blp";
 local buttonNoXP = "";
 if (activeFriend == ft["name"]) then
  buttonBg = "Interface/BUTTONS/UI-CheckBox-Check.blp";
 end
 if (ft["xpdisabled"] == 1) then
  buttonNoXP = "Interface/BUTTONS/UI-GroupLoot-Pass-Up.blp";
 end
 frame.button:SetScript("OnMouseDown", function() self:Debug("Setting activeFriend to " .. ft["name"]); if (activeFriend ~= ft["name"]) then activeFriend = ft["name"]; self:UpdateFriendXP_HELPER(activeFriend); else activeFriend = ""; end; self:UpdateMiniframe(); end)
 frame.buttonbg:SetPoint("LEFT", frame, "LEFT", -db.xp.height, 0);
 frame.buttonbg:SetHeight(db.xp.height);
 frame.buttonbg:SetWidth(db.xp.height);
 frame.buttonbg:SetBackdrop({bgFile = buttonNoXP, tile = false, tileSize = 0, edgeSize = 0, insets = { left = 0, right = 0, top = 0, bottom = 0}})
 frame.button:SetBackdrop({bgFile = buttonBg, tile = false, tileSize = 0, edgeSize = db.border.bordersize, insets = { left = 0, right = 0, top = 0, bottom = 0 }})
end

function FriendXP:RemoveOutdated()
 for key, value in pairs(friends) do
  if (key ~= UnitName("player")) then
   if (friends[key]["lastTime"] < GetTime() - self.db.profile.miniframe.threshold) then
    self:RemoveFromActive(key)
    self:RecycleFrame(key)
   end
  end
 end
end

function FriendXP:GetCreateXPBar(key)
 if (miniframes[key] ~= nil) then
  self:Debug("Updating " .. key)
  return miniframes[key]
 else
  -- Fetch a frame
  local frame = next(frameCache)
  if frame then
    self:Debug("Recycling " .. key);
    frameCache[frame] = nil;
    miniframes[key] = frame;
    return miniframes[key]
  else
   self:Debug("Creating " .. key);
   frame = CreateFrame("StatusBar", nil, Miniframe, BackdropTemplateMixin and "BackdropTemplate")
   frame.xp = CreateFrame("StatusBar", nil, frame, BackdropTemplateMixin and "BackdropTemplate")
   frame.bg = frame:CreateTexture(nil, 'BACKGROUND')
   frame.text = frame.xp:CreateFontString(nil, 'OVERLAY')
   frame.buttonbg = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate")
   frame.button = CreateFrame("Button", nil, frame.buttonbg)
   frame.button:RegisterForClicks("AnyDown")
   frame.button:ClearAllPoints()
   frame.button:SetAllPoints(true)
   miniframes[key] = frame;
   return miniframes[key]
  end
 end
end

function FriendXP:GetFrame(name) -- Player name is new frame ref thingy
 if (miniframes[name] ~= nil) then
  self:Debug("Updating" .. name)
  return miniframes[name]
 end
 local frame = next(frameCache)
 if frame then
  self:Debug("Recycling " .. name);
  frameCache[frame] = nil;
  miniframes[name] = frame
  return frame
 else
  self:Debug("Creating " .. name);
  frame = CreateFrame("StatusBar", nil, Miniframe, BackdropTemplateMixin and "BackdropTemplate")
  frame.id = y
  frame.xp = CreateFrame("StatusBar", nil, frame, BackdropTemplateMixin and "BackdropTemplate")
  frame.xp:SetAllPoints(true)
  frame.bg = frame:CreateTexture(nil, 'BACKGROUND')
  frame.text = frame.xp:CreateFontString(nil, 'OVERLAY')
  frame.buttonbg = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate")
  frame.button = CreateFrame("Button", nil, frame.buttonbg, BackdropTemplateMixin and "BackdropTemplate")
  frame.button:RegisterForClicks("AnyDown")
  frame.button:ClearAllPoints()
  frame.button:SetAllPoints(true)
  miniframes[name] = frame;
  return frame
 end
end

-- Need to first RemoveFromActive("friend")
-- then RecycleFrame to hide their miniframe if it exists
function FriendXP:RecycleFrame(name) -- Key is Y
 if (miniframes[name] ~= nil) then
  self:Debug("Recycling Frame " .. name);
  miniframes[name]:Hide()
  miniframes[name]:ClearAllPoints()
  frameCache[miniframes[name]] = true
  miniframes[name] = nil;
 end
end

function FriendXP:RecycleAllFrames()
 for key, value in pairs(miniframes) do
  if (miniframes[key] ~= nil) then
   self:Debug("RecycleAllFrames recycling " .. key)
   self:RecycleFrame(key)
  end
 end
end

function FriendXP:OnInitialize()
 local maxwidth = self:Round(UIParent:GetWidth(),0)
 local maxheight = self:Round(UIParent:GetHeight(),0)
-- defaults that are commented out need to be removed later
 local defaults = { -- Still needs work on better out of the box defaults
  profile = {
   enabled = true,
   version = 1.09,
   debug = false,
   checkOnline = true,
   integrateParty = true,
   sendAll = false,
   partyAll = true,
   bgAll = false,
   guildAll = false,
   ignoreWhisper = false,
   onlyFriends = false,
   doLevelUp = true,
   grid2 = false,
   friendbar = {
    enabled = false,
	personal = false,
	tile = false,
    framelevel = 1,
    framestrata = "MEDIUM",
    x = maxwidth/2 - (maxwidth*0.75)/2,
    y = -20,
    formatstring = "%n (%l): %xp / %txp (%p%) Remaining: %rm%rs Rested: %r%re %d",
    height = 16,
    width = 0.50,
    texture = "Blizzard",
    color = { -- Experience Bar Color, Purple
     r = 0.6,
     g = 0,
     b = 0.6,
    },
    rest = { -- Rest Bar Color, Blue
     r = 0.25,
     g = 0.25,
     b = 1,
    },
    bgcolor = {
     r = 0,
     g = 0,
     b = 0,
     a = 0.5,
    },
    text = {
     font = "Friz Quadrata TT",
     size = 12,
     style = "",
     color = {
      r = 0,
      g = 1,
      b = 0,
      a = 1,
     },
    },
   },
   miniframe = {
    rest = {
     enabled = true,
     custom = false,
     color = {
      r = 0,
      g = 0,
      b = 1,
     },
    },
    tooltip = {
     enabled = true,
     combatDisable = true,
    },
	ignoremaxlevel = false,
    formatstring = "%l: %n",
    enabled = true,
    framelevel = 1,
    framestrata = "MEDIUM",
    threshold = 180,
    x = 20,
    y = -maxheight + 400,
    friendlimit = 10,
    columnlimit = 5,
    incoming = {
     enabled = false,
     x = 0,
     y = -16,
     width = 32,
     height = 32,
     texture = "Wireless Incoming",
     point = "BOTTOMRIGHT",
     relativePoint = "TOPRIGHT",
    },
    outgoing = {
     enabled = true,
     x = 0,
     y = 16,
     width = 32,
     height = 32,
     texture = "Wireless Icon",
     point = "TOPLEFT",
     relativePoint = "TOPLEFT",
    },
    border = {
     border = "Blizzard Dialog", -- Whatever the default, need to include it myself
     bordersize = 16,
     color = {
      r = 1,
      g = 0,
      b = 1,
      a = 1,
     },
     inset = {
      left = 4,
      right = 4,
      top = 4,
      bottom = 4,
     },
    },
    texture = "Solid",
    bgcolor = {
     r = 0,
     g = 0,
     b = 0,
     a = 0.5,
    },
    xp = {
     texture = "Blizzard",
     bgcolor = {
      r = 1,
      g = 0,
      b = 0,
      a = 0.5,
     },
     color = {
      r = 1,
      g = 1,
      b = 1,
     },
     custom = false,
     namelen = 0,
     offsetx = 10,
     offsety = 6,
     height = 16,
     width = 80,
     text = {
      font = "Friz Quadrata TT",
      size = 10,
      style = "", -- Not yet implemented
      color = {
       r = 1,
       g = 1,
       b = 1,
       a = 1,
      },
     },
    },
   },
   pf = {
    enabled = false,
    tooltip = false,
	formatstring = "%n (%p%)",
	texture = "Blizzard",
	rest = {
	 r = 0.25,
	 g = 0.25,
	 b = 1,
	},
	color = {
	 r = 0.6,
	 g = 0,
	 b = 0.6,
	},
	bgcolor = {
	 r = 0,
	 g = 0,
	 b = 0,
	 a = 0.7,
	},
   },
   partyframes = {
    enabled = false,
    tooltip = false,
    formatstring = "%p%",
    texture = "Blizzard",
    rested = {
     r = 0.25,
     g = 0.25,
     b = 1,
    },
    xp = {
     r = 0.6,
     g = 0,
     b = 0.6,
    },
   },
   tooltip = {
    header = {
     font = "Friz Quadrata TT",
     size = 16,
     color = {
      r = 1,
      g = 0,
      b = 0,
     },
    },
    normal = {
     font = "Friz Quadrata TT",
     size = 12,
     color = {
      r = 1,
      g = 1,
      b = 1,
     },
    },
   },
  },
 }
 self.db = LibStub("AceDB-3.0"):New("FriendXPDB", defaults, true)
 self.db.RegisterCallback(self, "OnProfileChanged", "UpdateDb")
 self.db.RegisterCallback(self, "OnProfileCopied", "UpdateDb")
 self.db.RegisterCallback(self, "OnProfileReset", "UpdateDb")
 self:CreateFriendXPBar()
 LSM.RegisterCallback(self, "LibSharedMedia_Registered","UpdateMedia")
 self:RegisterChatCommand("friendxp","HandleIt")
 self:RegisterEvent("PLAYER_ENTERING_WORLD","WorldEnter")
 self:RegisterComm("friendxp")
 --self:RegisterAddonMessagePrefix("friendxp")
 self.fonts = { }
 self:CreateFonts()
 self:SetupMiniframe()
 self:HookBlizzPartyFrames()
 self:SetupGrid2()
 self:SetEnabledState(self.db.profile.enabled)
end

function FriendXP:CreateFonts()
 self.fonts["class"] = { }
 fonts["header"] = CreateFont("FriendXPFontHeader")
 fonts["header"]:SetFont(LSM:Fetch("font", FriendXP.db.profile.tooltip.header.font),self.db.profile.tooltip.header.size, "")
 fonts["header"]:SetTextColor(self.db.profile.tooltip.header.color.r, self.db.profile.tooltip.header.color.g, self.db.profile.tooltip.header.color.b)
 fonts["normal"] = CreateFont("FriendXPFontNormal")
 fonts["normal"]:SetFont(LSM:Fetch("font", FriendXP.db.profile.tooltip.normal.font), self.db.profile.tooltip.normal.size, "")
 fonts["normal"]:SetTextColor(self.db.profile.tooltip.normal.color.r, self.db.profile.tooltip.normal.color.g, self.db.profile.tooltip.normal.color.b)
--RAID_CLASS_COLORS[class]["r"], RAID_CLASS_COLORS[class]["g"], RAID_CLASS_COLORS[class]["b"]
 for i, v in pairs(RAID_CLASS_COLORS) do
  self.fonts["class"][i] = CreateFont("FriendXPClassColor" .. i)
  self.fonts["class"][i]:SetFont(LSM:Fetch("font", self.db.profile.tooltip.normal.font), self.db.profile.tooltip.normal.size, "")
  self.fonts["class"][i]:SetTextColor(RAID_CLASS_COLORS[i]["r"], RAID_CLASS_COLORS[i]["g"], RAID_CLASS_COLORS[i]["b"])
 end
end

-- Made this long time ago, seems like it needs improvement
function FriendXP:UpdateFonts(thing, size, r, g, b)
 if (not fonts[thing]) then
  return
 end
 local things = self.db.profile.tooltip
 fonts[thing]:SetFont(LSM:Fetch("font", things[thing]["font"]), size, "")
 fonts[thing]:SetTextColor(r, g, b)
end

function FriendXP:UpdateFont(thing)
 if (not fonts[thing]) then
  return
 end

 local things = self.db.profile.tooltip
 fonts[thing]:SetFont(LSM:Fetch("font", things[thing]["font"]), things[thing]["size"], "")
 fonts[thing]:SetTextColor(things[thing]["color"]["r"], things[thing]["color"]["g"], things[thing]["color"]["b"])
end

function FriendXP:UpdateFONTS() -- Going do something about all these update fonts someday; also do I really need a font for every class color
 for i, v in pairs(RAID_CLASS_COLORS) do
  self.fonts["class"][i]:SetFont(LSM:Fetch("font", self.db.profile.tooltip.normal.font), self.db.profile.tooltip.normal.size, "")
  self.fonts["class"][i]:SetTextColor(RAID_CLASS_COLORS[i]["r"], RAID_CLASS_COLORS[i]["g"], RAID_CLASS_COLORS[i]["b"])
 end
end

function FriendXP:UpdateMedia(event, mediatype, key)
 local doUpdate = false
 if mediatype == "font" then
  if key == self.db.profile.friendbar.text.font then doUpdate = true end
  if key == self.db.profile.tooltip.header.font then doUpdate = true end
  if key == self.db.profile.tooltip.normal.font then doUpdate = true end
 elseif mediatype == "statusbar" then
  if key == self.db.profile.friendbar.texture then doUpdate = true end
 elseif mediatype == "border" then
  if key == self.db.profile.miniframe.border.border then doUpdate = true end
 elseif mediatype == "background" then
  if key == self.db.profile.miniframe.texture then doUpdate = true end
  if key == self.db.profile.miniframe.outgoing.texture then doUpdate = true end
  if key == self.db.profile.miniframe.incoming.texture then doUpdate = true end
 end

 if doUpdate then
  self:UpdateSettings();
  self:UpdateFont("header");
  self:UpdateFont("normal");
  self:UpdateFONTS();
  self:SetupMiniframe();
  self:UpdateMiniframe();
 end
end

function FriendXP:UpdateDb()
 self:UpdateSettings();
 self:SetupMiniframe();
 self:UpdateMiniframe();
 self:UpdateFonts("header", self.db.profile.tooltip.header.size, self.db.profile.tooltip.header.color.r, self.db.profile.tooltip.header.color.g, self.db.profile.tooltip.header.color.b)
 self:UpdateFonts("normal", self.db.profile.tooltip.normal.size, self.db.profile.tooltip.normal.color.r, self.db.profile.tooltip.normal.color.g, self.db.profile.tooltip.normal.color.b)
end

function FriendXP:OnEnable()
 self:RegisterBucketEvent({ "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "ENABLE_XP_GAIN", "DISABLE_XP_GAIN" }, 2, "SendXP")
 self:ScheduleRepeatingTimer("SendXP", 45)
 self:UpdateSettings()

 if (self.db.profile.friendbar.enabled == true and self.db.profile.enabled) then
  xpbar:Show()
 else
  xpbar:Hide()
 end
 if (self.db.profile.miniframe.enabled == true and self.db.profile.enabled) then
  Miniframe:Show()
 else
  Miniframe:Hide()
 end
end

function FriendXP:OnDisable() -- FIX ME, Check if this is even called; also hide party/player xp frames
	self:UnregisterAllBuckets()
	self:CancelAllTimers()
	xpbar:Hide()
	Miniframe:Hide()
end

function FriendXP:ToggleFriendbar()
 if (self.db.profile.friendbar.enabled and self.db.profile.enabled) then
  xpbar:Show()
 else
  xpbar:Hide()
 end
end

function FriendXP:WorldEnter()
 LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("FriendXP", giveOptions(FriendXP))  -- I do this here instead of in OnInitialize() because values are accurate now
 self.configFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("FriendXP", "FriendXP")
 self:UnregisterEvent("PLAYER_ENTERING_WORLD")

 configGenerated = true

 self:SendXP()
end

function FriendXP:HandleIt(input)
 if not input then return end

 local command, nextposition = self:GetArgs(input,1,1)

 if (command == "active") then
  for i,v in ipairs(activeFriends) do
   self.Print(self,"Index",i,"Name",activeFriends[i]["name"])
  end
  return
 end

 if (command == "togglelock") then
  self:ToggleLock()
  return
 end

 if (command == "toggle") then
  local nc = self:GetArgs(input, 1, nextposition)

  if (nc == "miniframe") then
   if (self.db.profile.miniframe.enabled) then
    self.db.profile.miniframe.enabled = false
   else
    self.db.profile.miniframe.enabled = true
   end
   self:SetupMiniframe()
  elseif (nc == "xpbar") then
   if (self.db.profile.friendbar.enabled) then
    self.db.profile.friendbar.enabled = false
   else
    self.db.profile.friendbar.enabled = true
   end
   self:ToggleFriendbar()
  elseif (nc == "blizz") then
   if (self.db.profile.integrateParty) then
    self.db.profile.integrateParty = false
   else
    self.db.profile.integrateParty = true
   end
   self:HookBlizzPartyFrames()
  end
  return
 end

 if (command == "send") then
  self:SendXP()
  self:UpdateMiniframe()
  self:Print("Sent experience")
  return
 end
 
 LibStub("AceConfigDialog-3.0"):Open("FriendXP")
end

function FriendXP:SendXP()
	if (self.db.profile.miniframe.enabled and self.db.profile.miniframe.outgoing.enabled) then
		Miniframe.flash:Show()
	end

 local restbonus = GetXPExhaustion()
 local xpdisabled = false
 if (restbonus == nil) then restbonus = 0 end
 if (xpdisabled == true) then xpdisabled = 1 else xpdisabled = 0 end

 local player = UnitName("player");
 local xp = UnitXP("player");
 local xptotal = UnitXPMax("player");
 local level = UnitLevel("player");
 local _, class = UnitClass("player");
 local maxlevel = MAX_PLAYER_LEVEL_TABLE[GetExpansionLevel()]
 friends[player] = {
  name = player,
  xp = xp,
  totalxp = xptotal,
  level = level,
  restbonus = restbonus,
  xpdisabled = xpdisabled,
  class = class,
  lastTime = GetTime(),
  maxlevel = maxlevel,
 }

 self:UpdateMiniframe()

 if (activeFriend == player or self.db.profile.friendbar.personal) then -- If the player is selected to be shown on the friendbar, then do update
  self:UpdateFriendXP_HELPER(player)
 end


 self:HandlePlayerXP(xp,xptotal, restbonus)

 local msg = self:Serialize(player, xp, xptotal, level, restbonus, xpdisabled, class, maxlevel)

 if (self.db.profile.guildAll == true and IsInGuild()) then -- Send to entire guild
  self:Debug("Sending xp to GUILD")
  self:SendCommMessage("friendxp", msg, "GUILD")
 end
 if (self.db.profile.partyAll) then
  local channel = nil
  if (IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) then
   channel = "INSTANCE_CHAT"
  elseif (IsInRaid()) then
   channel = "RAID"
  elseif (IsInGroup()) then
   channel = "PARTY"
  end

  if (channel) then
   self:Debug("Sending to " .. channel)
   self:SendCommMessage("friendxp", msg, channel, friend)
  end
 end

 if (self.db.profile.sendAll == true) then -- Send to all friends
  local numberOfFriends, onlineFriends = C_FriendList.GetNumFriends() -- Normal friends first
  if (numberOfFriends > 0) then
   for i = 1, numberOfFriends do
    local nameT, _, _, _, connectedT, _, _ = C_FriendList.GetFriendInfo(i)
    if (nameT ~= nil and connectedT) then
	  self:Debug("Sending whisper to" .. nameT)
	  self:SendCommMessage("friendxp", msg, "WHISPER", nameT)
    end
   end
  end
	-- FIX ME Check if this friend stuff still works
  local BNFriends, _ = BNGetNumFriends() -- Then do RealID/BattleTag Friends, doesn't work with connected realms
  if (BNFriends > 0) then
   for i = 1, BNFriends do
    local presenceID, presenceName, battleTag, isBattleTagPresence, toonName, toonID, client, isOnline, _, _, _, _, _, isRIDFriend, _, _  = BNGetFriendInfo(i)
	for gameAccountIndex = 1, BNGetNumFriendGameAccounts(i) do
     self:Debug("Processing BattleNet: " .. presenceName)
	 if (isOnline and toonName) then
	  local _, _, client, realmName, _, _, _, _, _, _, _ = BNGetFriendGameAccountInfo(i, gameAccountIndex)
	  if (client == BNET_CLIENT_WOW and realmName == GetRealmName() and CanCooperateWithGameAccount(toonID)) then
	   self:Debug("Sent")
	   self:SendCommMessage("friendxp", msg, "WHISPER", toonName)
	  end
	 end
	end
   end
  end
 end
 if self.db.profile.grid2 and self.grid2setup then -- But update grid 2 anyway
	self.updateGrid2()
 end
end

-- prefix, message, distribution, sender
function FriendXP:OnCommReceived(a,b,c,d)
 self:Debug("OnCommReceived: Prefix " .. a .. ":" .. b .. ":" .. ", Channel " .. c .. ":" .. d)
 if (a ~= "friendxp") then return end

 if (c == "GUILD" and not self.db.profile.guildAll) then return end
--[[ if (c == "BATTLEGROUND" and self.db.profile.bgAll == false) then -- Only process BATTLEGROUND if Send to bg is enabled
  return
 end
]]--
 if ((c == "RAID" or c == "PARTY" or c == "INSTANCE_CHAT") and not self.db.profile.partyAll) then return end
 if (c == "WHISPER" and self.db.profile.ignoreWhisper == true) then return end

 local success, name, xp, xptotal, level, restbonus, xpdisabled, class, maxlevel = self:Deserialize(b)
 if (not success) then
  self:Debug("Could not deserialize message")
  return
 end

 self:Debug(name .. " " .. xp .. " " .. xptotal .. " " .. level .. " " .. restbonus .. " " .. class .. " " .. maxlevel)

 if (UnitName("player") == name) then -- Don't show stuff we sent, mainly for PARTY and GUILD
  
  self:Debug("Returning from OnComm because name == player")
  return
 end
 -- Make sure player is only sending their info
 -- add cross realm support to tell between Player and Player-Realm
 if (strupper(name) ~= strupper(d)) then
  --self:Print(name,d)
  local Tmid = string.find(d, "-", 1, true)
  if (Tmid) then
   self:Debug("Tmid " .. Tmid)
   local Tname = string.sub(d, 1, Tmid - 1)
   self:Debug("Name Tname" .. name .. " " .. Tname)
   if (strupper(name) ~= strupper(Tname)) then
    --self:Print(name,Tname)
    self:Debug("Sending player is not equal to sent string")
    --return 
   end
  else
   self:Debug("Sending player is not equal to sent string")
   --return -- Names didn't match and not from different realm FIXME
  end
 end

 if (self.db.profile.onlyFriends and not self:FriendCheck(GetRealmName(), name)) then
  self:Debug("not processing " .. name .. ", because onlyFriends")
  return
 end

 if (restbonus == nil) then restbonus = 0 end
 if (xpdisabled == nil) then xpdisabled = 0 end

 if (name ~= nil and xp ~= nil and xptotal ~= nil and level ~= nil and class ~= nil and maxlevel ~= nil) then
  if (self.db.profile.miniframe.enabled and self.db.profile.miniframe.incoming.enabled) then -- Only flash on valid updates
   Miniframe.incoming:Show()
  end

  if (self.db.profile.doLevelUp) then
   local previousLevel = self:GetLevelByPlayer(name)
   if (previousLevel ~= nil and previousLevel < tonumber(level)) then
    self:DoLevelUp(name, level)
   end
  end

  end
 friends[name] = {
  name = name,
  xp = tonumber(xp),
  totalxp = tonumber(xptotal),
  level = tonumber(level),
  restbonus = tonumber(restbonus),
  xpdisabled = tonumber(xpdisabled),
  class = class,
  lastTime = GetTime(),
  maxlevel = tonumber(maxlevel)
 }

 self:UpdateFriendXP_HELPER(name)
 self:UpdateMiniframe()
 if self.db.profile.grid2 and self.grid2setup then
	--print("Updating all things for grid2")
	self.updateGrid2()
 end
end

function FriendXP:RemoveFromActive(friend)
 if (friends[friend]) then
  self:Debug("Removing " .. friend .. " from friends table")
  friends[friend] = nil

 end
end

function FriendXP:GetLevelByPlayer(friend)
 if (friends[friend]) then
  self:Debug("GetLevelByPlayer returning friends entry")
  return friends[friend]["level"]
 end

 return nil
end

function FriendXP:DoLevelUp(friend, level)
 UIErrorsFrame:AddMessage(friend .. " has reached level " .. level .. "!", 1.0, 1.0, 0.0, 1, 5)
 --PlaySoundFile("Sound\\interface\\LevelUp.wav"
 PlaySound(888) -- Level up sound
 return
end

function FriendXP:Round(n, precision, roundDown)
 local m = 10^(precision or 0)

 if (roundDown) then
  return floor(m*n)/m
 else
  return floor(m*n + 0.5)/m
 end
end

-- Cycles through friend list and real id friends to see if any given friend is online
-- Maybe should just cache this information somehow
-- Doesn't support connected realms and I don't intend to fix it
function FriendXP:FriendCheck(realm, friend)
 local numberOfFriends, onlineFriends = GetNumFriends()
 local numberOfBFriends, BonlineFriends = BNGetNumFriends()
 if (onlineFriends > 0) then
  for i = 1, onlineFriends do
   local name, level, class, area, connected, status, note = GetFriendInfo(i)
   --self:Print("FriendINFO: ", name, level, class, area, connected, status, note)
   --self:Print(realm, friend)
   if (name == friend and realm == GetRealmName()) then
    return true
   end
  end
 end
 if (BonlineFriends > 0) then
  for Bfriend = 1,BonlineFriends do
  local presenceID, presenceName, battleTag, isBattleTagPresence, toonName, toonID, client, isOnline, lastOnline, isAFK, isDND, messageText, noteText, isRIDFriend, messageTime, canSoR  = BNGetFriendInfo(Bfriend)
   if (toonID and CanCooperateWithGameAccount(toonID) or UnitInParty(toonName)) then
    if (toonName == friend) then
     return true
    end
   end
  end
 end

 return false
end

function FriendXP:Debug(msg)
 if (not self.db.profile.debug) then
  return
 end

 self.Print(self,"Debug",msg)
end

function FriendXP.LDB.OnEnter(self)
	local tooltip

	if WoWClassic then
		tooltip = LQT:Acquire("FriendXP", 4, "LEFT", "RIGHT", "RIGHT", "RIGHT")
		tooltip:AddHeader(L["Name"], L["Level"], L["XP"], L["Rest Bonus"])
	else
		tooltip = LQT:Acquire("FriendXP", 5, "LEFT", "RIGHT", "RIGHT", "RIGHT", "RIGHT")
		tooltip:AddHeader(L["Name"], L["Level"], L["XP"], L["Rest Bonus"], L["XPDisabled"])
	end
	self.tooltip = tooltip
	if _G.TipTac and _G.TipTac.AddModifiedTip then
		_G.TipTac:AddModifiedTip(self.tooltip, true)
	end
	tooltip:SetHeaderFont(fonts["header"])
	tooltip:SetFont(fonts["normal"])
	tooltip:AddSeparator()
	for key, value in pairs(friends) do
		local ft = friends[key]
			local xpdisablemsg = "";
		if (ft["xpdisabled"] == 1 and not WoWClassic) then
			xpdisablemsg = "XP Disabled";
		end
		tooltip:AddLine(ft["name"],ft["level"],ft["xp"] .. "/" .. ft["totalxp"],ft["restbonus"], xpdisablemsg)
	end
	tooltip:SmartAnchorTo(self)
	tooltip:Show()
end

function FriendXP.LDB.OnLeave(self)
	LQT:Release(self.tooltip)
	self.tooltip = nil
end

function FriendXP:MiniTooltip(frame, show, fd)
 if (show) then
  if not self.db.profile.miniframe.tooltip.enabled then return end
  if (InCombatLockdown() and self.db.profile.miniframe.tooltip.combatDisable) then return end
  
  local tooltip = LQT:Acquire("FriendXP", 2, "LEFT", "RIGHT")
  self.tooltip = tooltip

  local rested = (fd["restbonus"] / ((fd["totalxp"] / 100) * 1.5))
  rested = self:Round(rested,1) .. "%"

  tooltip:SetFont(self.fonts["class"][fd["class"]])
  tooltip:AddLine(fd["name"])
  tooltip:SetFont(fonts["normal"])
  tooltip:AddLine(L["Level"] .. ":", fd["level"])
  tooltip:AddLine(L["Experience"] .. ":", fd["xp"] .. "/" .. fd["totalxp"] .. " (" .. self:Round((fd["xp"]/fd["totalxp"])*100) .. "%)")
  tooltip:AddLine(L["Rest Bonus"] .. ":", fd["restbonus"])
  tooltip:AddLine(L["Rest Percent"] .. ":", rested)
  tooltip:AddLine(L["Remaining"] .. ":", fd["totalxp"] - fd["xp"])
  tooltip:AddLine(L["Bars Left"] .. ":", self:Round((100 - ((fd["xp"] / fd["totalxp"]) * 100)) / 5, 0))
  if (fd["xpdisabled"] == 1) then
   tooltip:AddLine(L["XPDisabled"])
  end
  tooltip:SmartAnchorTo(frame)
  tooltip:Show()
 else
  LQT:Release(self.tooltip)
  self.tooltip = nil
 end
end

function FriendXP:Tooltip(frame, show, unit)
 if (show) then
  if (InCombatLockdown() and self.db.profile.miniframe.tooltip.combatDisable) then
   return
  end

  local name = UnitName(unit)
  if (name == nil) then return end

  local fd = self:FetchFriend(name)

  if (fd == nil) then return end

  local tooltip = LQT:Acquire("FriendXP", 2, "LEFT", "RIGHT")
  self.tooltip = tooltip


  local rested = (fd["restbonus"] / ((fd["totalxp"] / 100) * 1.5))
  rested = self:Round(rested,1) .. "%"

  tooltip:SetFont(self.fonts["class"][fd["class"]])
  tooltip:AddLine(fd["name"])
  tooltip:SetFont(fonts["normal"])
  tooltip:AddLine(L["Level"] .. ":", fd["level"])
  tooltip:AddLine(L["Experience"] .. ":", fd["xp"] .. "/" .. fd["totalxp"] .. " (" .. self:Round((fd["xp"]/fd["totalxp"])*100) .. "%)")
  tooltip:AddLine(L["Rest Bonus"] .. ":", fd["restbonus"])
  tooltip:AddLine(L["Rest Percent"] .. ":", rested)
  tooltip:AddLine(L["Remaining"] .. ":", fd["totalxp"] - fd["xp"])
  tooltip:AddLine(L["Bars Left"] .. ":", self:Round((100 - ((fd["xp"] / fd["totalxp"]) * 100)) / 5, 0))
  if (fd["xpdisabled"] == 1) then
   tooltip:AddLine(L["XPDisabled"])
  end
  tooltip:SmartAnchorTo(frame)
  tooltip:Show()
 else
  LQT:Release(self.tooltip)
  self.tooltip = nil
 end
end

function FriendXP:ToggleLock()
 if (not self.unlocked) then
  Miniframe.move:ClearAllPoints()
  Miniframe.move:SetFrameStrata("TOOLTIP")
  Miniframe.move:SetPoint("TOPLEFT", UIParent, "TOPLEFT", self.db.profile.miniframe.x, self.db.profile.miniframe.y);
  Miniframe.move:SetWidth(Miniframe:GetWidth())
  Miniframe.move:SetHeight(Miniframe:GetHeight())
  Miniframe.move:Show()
  Miniframe.move:SetMovable(true)
  Miniframe.move:EnableMouse(true)
  Miniframe.move:SetScript("OnMouseDown", function(self, button) FriendXP:DragStart(self, button, "miniframe") end)
  Miniframe.move:SetScript("OnMouseUp", function(self, button) FriendXP:DragStop(self, button, "miniframe") end)
  Miniframe:SetAllPoints(Miniframe.move)

  xpbar.move:ClearAllPoints()
  xpbar.move:SetFrameStrata("TOOLTIP")
  xpbar.move:SetPoint("TOPLEFT", UIParent, "TOPLEFT", self.db.profile.friendbar.x, self.db.profile.friendbar.y)
  xpbar.move:SetWidth(xpbar:GetWidth())
  xpbar.move:SetHeight(xpbar:GetHeight())
  xpbar.move:Show()
  xpbar.move:SetMovable(true)
  xpbar.move:EnableMouse(true)
  xpbar.move:SetScript("OnMouseDown", function(self, button) FriendXP:DragStart(self, button, "friendbar") end)
  xpbar.move:SetScript("OnMouseUp", function(self, button) FriendXP:DragStop(self, button, "friendbar") end)
  xpbar:SetAllPoints(xpbar.move)

  self.unlocked = true
 else
  self.unlocked = false
  Miniframe.move:Hide()
  Miniframe.move:SetMovable(false)
  Miniframe.move:EnableMouse(false)
  Miniframe.move:SetScript("OnMouseDown", nil)
  Miniframe.move:SetScript("OnMouseUp", nil)

  xpbar.move:Hide()
  xpbar.move:SetMovable(false)
  xpbar.move:EnableMouse(false)
  xpbar.move:SetScript("OnMouseDown", nil)
  xpbar.move:SetScript("OnMouseUp", nil)
  self:SetupMiniframe()
  self:UpdateSettings()
 end
end

function FriendXP:DragStart(frame, button, name)
 if (button == "LeftButton" and not frame.isMoving) then
  frame.isMoving = true
  frame:StartMoving()
 end
end

function FriendXP:DragStop(frame, button, name)
 if (button == "LeftButton" and frame.isMoving == true) then
  local maxheight = self:Round(UIParent:GetHeight(),0);
  frame.isMoving = false
  self.db.profile[name].x = self:Round(frame:GetLeft(), 0)
  self.db.profile[name].y = -maxheight + self:Round(frame:GetTop(), 0)

  frame:StopMovingOrSizing()

 end
end

local partyXPFrames = { }
--FriendXP.tmp = partyXPFrames -- FIXME (Just to allow me access within WoW for testing)
function FriendXP:HookBlizzPartyFrames()
 for i = 1, 4 do -- Hide all frames
  if (partyXPFrames[i]) then partyXPFrames[i]:Hide() end
 end
 if (not self.db.profile.integrateParty) then return end
 for i = 1, 4 do
  if (partyXPFrames[i] == nil) then
   local partyXP = CreateFrame("Frame", nil, _G["PartyMemberFrame" .. i], BackdropTemplateMixin and "BackdropTemplate")
   partyXP:SetBackdrop({bgFile = LSM:Fetch("background", "Solid")})
   partyXP:SetBackdropColor(0,0,0,.5)
   partyXP:SetPoint("TOPLEFT", _G["PartyMemberFrame" .. i], "TOPLEFT", 46, -31)
   partyXP:SetWidth(66)
   partyXP:SetHeight(4)
   partyXP.frame = CreateFrame("Frame", nil, partyXP, BackdropTemplateMixin and "BackdropTemplate")
   partyXP.frame:SetBackdrop({bgFile = LSM:Fetch("background", "PartyXPBar"), tile = false, tileSize = 0, insets = { left = 0, right = 0, top = 0, bottom = 0 }})
   partyXP.frame:ClearAllPoints()
   partyXP.frame:SetHeight(32)
   partyXP.frame:SetWidth(128)
   partyXP.frame:SetPoint("TOPLEFT", _G["PartyMemberFrame" .. i], "TOPLEFT", 42, -30)

   partyXP.restbar = CreateFrame("StatusBar", nil, partyXP)
   partyXP.restbar:SetAllPoints(true)

   partyXP.restbar:SetStatusBarTexture(LSM:Fetch("statusbar", self.db.profile.partyframes.texture))
   partyXP.restbar:SetStatusBarColor(self.db.profile.partyframes.rested.r, self.db.profile.partyframes.rested.g, FriendXP.db.profile.partyframes.rested.b)
   partyXP.restbar:SetMinMaxValues(0, 1000)
   partyXP.restbar:SetValue(200)

   partyXP.xpbar = CreateFrame("StatusBar", nil, partyXP.restbar)
   partyXP.xpbar:SetAllPoints(true)

   partyXP.xpbar:SetStatusBarTexture(LSM:Fetch("statusbar", self.db.profile.partyframes.texture))
   partyXP.xpbar:SetStatusBarColor(self.db.profile.partyframes.xp.r, FriendXP.db.profile.partyframes.xp.g, FriendXP.db.profile.partyframes.xp.b)
   partyXP.xpbar:SetMinMaxValues(0, 1000)
   partyXP.xpbar:SetValue(200)

   partyXP.text = partyXP.xpbar:CreateFontString(nil, 'OVERLAY')
   partyXP.text:SetFont(LSM:Fetch("font", "Friz Quadrata TT"), 10, "")
   partyXP.text:SetAllPoints(true)

   partyXP.lastUpdate = 0
   
   partyXP:SetScript("OnEnter", function() if (not self.db.profile.partyframes.tooltip) then return end self:Tooltip(partyXP, true,  "party" .. i) end)
   partyXP:SetScript("OnLeave", function() self:Tooltip(partyXP, false) end)

   --partyXP.frame:SetFrameLevel(partyXP.xpbar:GetFrameLevel() - 1)
   --partyXP.frame:Hide()

   partyXPFrames[i] = partyXP
   partyXPFrames[i]:SetScript("OnUpdate", function(self, elapsed)
   	   self.lastUpdate = self.lastUpdate + elapsed
   	   if (self.lastUpdate < 2) then return end
   	   self.lastUpdate = 0
   	   if (FriendXP.db.profile.integrateParty == false) then self:Hide() return end
   	   local xp, total, percent, restbonus = FriendXP:GetXPByUnit("party" .. i)
   	   if (xp ~= nil and total ~= nil and percent ~= nil and restbonus ~= nil) then
            if (restbonus > 0) then
             if (restbonus + xp >= total) then
              self.restbar:SetMinMaxValues(0, total)
              self.restbar:SetValue(total)
             else
              self.restbar:SetMinMaxValues(0, total)
              self.restbar:SetValue(xp + restbonus)
             end
            self.restbar:SetStatusBarColor(FriendXP.db.profile.partyframes.rested.r, FriendXP.db.profile.partyframes.rested.g, FriendXP.db.profile.partyframes.rested.b)
          --else
           self.xpbar:SetStatusBarColor(FriendXP.db.profile.partyframes.xp.r, FriendXP.db.profile.partyframes.xp.g, FriendXP.db.profile.partyframes.xp.b)
            else
			 self.restbar:SetMinMaxValues(0, 1)
			 self.restbar:SetValue(0)
			end
   	     self.xpbar:SetMinMaxValues(0, total)
   	     self.xpbar:SetValue(xp)
   	     self.text:SetText(percent .. "%")
	     self:SetAlpha(1)
   	    else
   	     self.xpbar:SetValue(0)
		 self.restbar:SetValue(0)
   	     self.text:SetText("N/A") -- Probably should just hide frame instead (But can't process OnUpdate then)
	     self:SetAlpha(0)
   	    end
   	   end)

  else
   --partyXPFrames[i].frame:SetBackdrop({bgFile = LSM:Fetch("background", self.db.profile.partyframes.texture), tile = false, tileSize = 0, insets = { left = 0, right = 0, top = 0, bottom = 0 }})
   partyXPFrames[i].xpbar:SetStatusBarTexture(LSM:Fetch("statusbar", self.db.profile.partyframes.texture)) -- FIXME This is probably not needed, they update every few seconds anyway
   partyXPFrames[i]:Show()
  end
 end
end

function FriendXP:GetXPByUnit(unit, formatString)
 self:Debug("GetXPByUnit called with " .. unit)
 local name, _ = UnitName(unit)
 if (name == nil) then return nil end

 local ft = self:FetchFriend(name)
 if (ft and formatString == nil) then
  return ft["xp"], ft["totalxp"], self:Round((ft["xp"]/ft["totalxp"])*100), ft["restbonus"]
 elseif(ft == nil and formatString == nil) then
  return nil, nil, nil, nil
 elseif (ft and formatString ~= nil) then
  return self:FormatString(formatString, ft)
 else
  return nil
 end
end

function FriendXP:HandlePlayerXP(xp, xptotal, restbonus)
 if (self.playerxp and not self.db.profile.pf.enabled) then PlayerName:SetText(self:GetXPByUnit("player", "%n")) self.playerxp:Hide() return end -- Probably replace with UnitName
 if (not self.playerxp and not self.db.profile.pf.enabled) then return end
 
 if (xp == nil) then xp = 0 end
 if (xptotal == nil) then xptotal = 100 end
 if (restbonus == nil) then restbonus = 0 end
 
 if (not self.playerxp) then
  --_G["PlayerFrame"]:SetFrameLevel(_G["PlayerFrame"]:GetFrameLevel() + 1)
  local frame = CreateFrame("Frame", nil, _G["PlayerFrame"], BackdropTemplateMixin and "BackdropTemplate")
  frame:SetBackdrop({bgFile = LSM:Fetch("statusbar", "Blizzard")})
  frame:SetBackdropColor(self.db.profile.pf.bgcolor.r, self.db.profile.pf.bgcolor.g, self.db.profile.pf.bgcolor.b, self.db.profile.pf.bgcolor.a)
  frame:SetPoint("TOPLEFT", _G["PlayerFrame"], "TOPLEFT", 90, -24)
  frame:SetWidth(116)
  frame:SetHeight(16)
  frame.rest = CreateFrame("StatusBar", nil, frame)
  frame.rest:SetAllPoints(true)
  frame.rest:SetStatusBarTexture(LSM:Fetch("statusbar", "Blizzard"))
  frame.rest:SetStatusBarColor(self.db.profile.pf.rest.r, self.db.profile.pf.rest.g, self.db.profile.pf.rest.b)
  frame.xp = CreateFrame("StatusBar", nil, frame.rest)
  frame.xp:SetAllPoints(true)
  frame.xp:SetStatusBarTexture(LSM:Fetch("statusbar", "Blizzard"))
  frame.xp:SetStatusBarColor(self.db.profile.pf.color.r, self.db.profile.pf.color.g, self.db.profile.pf.color.b)
--  frame.rest = CreateFrame("StatusBar", nil, frame)
--  frame.rest:SetStatusBarTexture(LSM:Fetch("statusbar", "Blizzard"))
--  frame.rest:SetAllPoints(true)
  self.playerxp = frame
  --frame:SetFrameLevel(1)
  frame:SetFrameStrata("BACKGROUND")
  
   self.tooltipFrame = CreateFrame("Frame", nil, _G["PlayerFrame"])
   self.tooltipFrame:SetPoint("TOPLEFT", _G["PlayerFrame"], "TOPLEFT", 110, -24)
   self.tooltipFrame:SetFrameStrata("HIGH")
   self.tooltipFrame:SetWidth(116)
   self.tooltipFrame:SetHeight(16)

   self.tooltipFrame:SetScript("OnEnter", function() if (not self.db.profile.pf.tooltip) then return end self:Tooltip(frame, true,  "player") end)
   self.tooltipFrame:SetScript("OnLeave", function() self:Tooltip(frame, false) end)
 end
 
 self.playerxp:Show()
 
 if (self.db.profile.pf.tooltip) then
  self.tooltipFrame:Show()
 else
  self.tooltipFrame:Hide()
 end
 
 if ((restbonus + xp) > xptotal) then restbonus = xptotal end
 self.playerxp.rest:SetMinMaxValues(0, xptotal)
 self.playerxp.rest:SetValue(restbonus + xp)
 self.playerxp.xp:SetMinMaxValues(0, xptotal)
 self.playerxp.xp:SetValue(xp)
 
 PlayerName:SetText(self:GetXPByUnit("player", self.db.profile.pf.formatstring))
end

function FriendXP:SetupGrid2()
	if not self.db.profile.grid2 or not IsAddOnLoaded("Grid2") or self.grid2setup then return end
	self.grid2setup = true
	GridFriendXP = Grid2.statusPrototype:new("FriendXP", false)
	GridFriendXP.GetColor = Grid2.statusLibrary.GetColor

	function GridFriendXP:IsActive(unit)
		--print("IsActive", unit)
		local name, _ = UnitName(unit)
		if (name == nil) then return false end
		local ft = FriendXP:FetchFriend(name)
		if ft == nil then return false end
		
		return true
	end

	function GridFriendXP:GetPercent(unit)
		local xp = FriendXP:GetXPByUnit(unit, "%p")
		if not xp then return end

		return tonumber(xp) * 0.01 
	end

	function GridFriendXP:GetText(unit)
		--print(FriendXP:GetXPByUnit(unit, self.dbx.formatString), unit, 'GetText')
		return FriendXP:GetXPByUnit(unit, self.dbx.formatString)
	end

	function GridFriendXP:GetColor(unit)
		return self.dbx.color1.r, self.dbx.color1.g, self.dbx.color1.b, self.dbx.color1.a
	end

	self.updateGrid2 = function() GridFriendXP:UpdateAllUnits() end -- Probably not ideal
	Grid2.setupFunc["FriendXP"] = function(baseKey, dbx)
		Grid2:RegisterStatus(GridFriendXP, {"text", "percent", "color"}, baseKey, dbx)

		return GridPlayerXP
	end

	Grid2:DbSetStatusDefaultValue("FriendXP", {type = "FriendXP", formatString = "%p%", colorCount = 1, color1 = {r=0.6,g=0,b=0.6,a=1}})
	if IsAddOnLoaded("Grid2Options") then
		Grid2Options:RegisterStatusOptions("FriendXP", "misc", function(self, status, options, optionParams)
		self:MakeStatusStandardOptions(status, options, optionParams)
		--self:MakeStatusColorOptions(status, options, optionParams)
		options.formatString = {
			type  = "input",
			name  = L["Format String"],
			desc  = L["Changes the text that is displayed"],
			get   = function ()	return status.dbx.formatString end,
			set   = function (_, v)	status.dbx.formatString = v status:UpdateAllUnits() end,
		}
		end, {
			titleIcon = "Interface\\ICONS\\INV_Misc_Gem_Variety_02",
		})
	end
end
