local Factory, AN, T = {}, ...
local C, EV, L, U, S = C_Garrison, T.Evie, T.L, T.Util, {}
local PROGRESS_MIN_STEP = 0.2
local CovenKit = "NightFae"
local tooltipSharedPB, tooltipShopWatch
local UIBUTTON_HEIGHT = ({zhCN=24, zhTW=24, koKR=24})[GetLocale()] or 22

local CreateObject do
	local skip, peekO = {SharedTooltipProgressBar=1, ObjectGroup=1, TexSlice=1, CommonHoverTooltip=1, Shadow=1}
	local function peek(k)
		local o = peekO and peekO[k]
		return o and o.GetObjectType and o or nil
	end
	local function ret(otype, ...)
		local a = ...
		local s, nf = S[a], VPEX_OnUIObjectCreated
		if a and not skip[otype] and type(nf) == "function" and (s or type(a) == "table") then
			local ar = a and a.GetObjectType and a or s and s.GetObjectType and s
			if ar then
				peekO = s and (ar == s and a or s) or nil
				securecall(nf, otype, ar, peek)
				peekO = nil
			end
		end
		return ...
	end
	function CreateObject(otype, ...)
		return ret(otype, assert(Factory[otype], otype)(...))
	end
end
T.Shadows, T.CreateObject = S, CreateObject

local function Mirror(tex, swapH, swapV)
	local ulX, ulY, llX, llY, urX, urY, lrX, lrY = tex:GetTexCoord()
	if swapH then
		ulX, ulY, llX, llY, urX, urY, lrX, lrY = urX, urY, lrX, lrY, ulX, ulY, llX, llY
	end
	if swapV then
		ulX, ulY, llX, llY, urX, urY, lrX, lrY = llX, llY, ulX, ulY, lrX, lrY, urX, urY
	end
	tex:SetTexCoord(ulX, ulY, llX, llY, urX, urY, lrX, lrY)
	return tex
end
local function AugmentFollowerInfo(info)
	info.autoCombatantStats = C_Garrison.GetFollowerAutoCombatStats(info.followerID)
	info.autoCombatSpells = C_Garrison.GetFollowerAutoCombatSpells(info.followerID, info.level)
	info.missionTimeEnd = info.missionTimeEnd or info.status == GARRISON_FOLLOWER_ON_MISSION and
		(GetTime() + (C_Garrison.GetFollowerMissionTimeLeftSeconds(info.followerID) or 1)) or nil
	return info
end

local GetTimeStringFromSeconds = U.GetTimeStringFromSeconds
local function HideOwnGameTooltip(self)
	if GameTooltip:IsOwned(self) then
		GameTooltip:Hide()
	end
end
local function CommonTooltip_ShopWatch()
	if not tooltipShopWatch or GameTooltip:IsForbidden() or GameTooltip:GetOwner() ~= tooltipShopWatch then
		tooltipShopWatch = nil
		return "remove"
	end
	if IsModifiedClick("COMPAREITEMS") or GetCVarBool("alwaysCompareItems") then
		GameTooltip_ShowCompareItem(GameTooltip, GameTooltip)
	else
		GameTooltip_HideShoppingTooltips(GameTooltip)
	end
end
local function CommonTooltip_ArmShopWatch(self, item)
	if IsEquippableItem(item) and tooltipShopWatch ~= self then
		if not tooltipShopWatch then
			EV.MODIFIER_STATE_CHANGED = CommonTooltip_ShopWatch
		end
		tooltipShopWatch = self
	end
end
local function CommonTooltip_OnEnter(self)
	local showCurrencyBar = false
	if self.tooltipAnchor == "ANCHOR_TRUE_LEFT" then
		GameTooltip:SetOwner(self, "ANCHOR_NONE")
		GameTooltip:SetPoint("RIGHT", self, "LEFT", self.tooltipXO or 0, self.tooltipYO or 0)
	else
		GameTooltip:SetOwner(self, self.tooltipAnchor or "ANCHOR_TOP", self.tooltipXO or 0, self.tooltipYO or 0)
	end
	tooltipShopWatch = not not tooltipShopWatch
	if type(self.mechanicInfo) == "table" then
		local ic, m = self.Icon and self.Icon:GetTexture(), self.mechanicInfo
		ic = ic or m.icon
		GameTooltip:SetText((ic and "|T" .. ic .. ":0:0:0:0:64:64:4:60:4:60|t " or "") .. m.name)
		if (m.enemy or "") ~= "" then
			GameTooltip:AddLine("|cff49C8F2" .. m.enemy)
		elseif (m.description or "") ~= "" then
			GameTooltip:AddLine(m.description, 1,1,1,1)
		end
		if type(m.ability) == "table" then
			local a = m.ability
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine((a.icon and "|T" .. a.icon .. ":0|t " or "") .. a.name)
			if (a.description or "") ~= "" then
				GameTooltip:AddLine(a.description, 1,1,1,1)
			end
		end
	elseif self.itemLink then
		GameTooltip:SetHyperlink(self.itemLink)
		CommonTooltip_ArmShopWatch(self, self.itemLink)
	elseif self.itemID then
		GameTooltip:SetItemByID(self.itemID)
		CommonTooltip_ArmShopWatch(self, self.itemID)
	elseif self.tooltipHeader and (self.tooltipText or self.tooltipCountdownTo) then
		GameTooltip:AddLine(self.tooltipHeader)
		if self.tooltipCountdownTo then
			GameTooltip:AddLine(GetTimeStringFromSeconds(self.tooltipCountdownTo - GetTime(), false, false, true), 1,1,1)
		else
			GameTooltip:AddLine(self.tooltipText, 1,1,1, self.tooltipTextNW == nil and 1 or nil)
		end
		showCurrencyBar = not not (self.currencyID)
	elseif self.currencyID then
		GameTooltip:SetCurrencyByID(self.currencyID)
		if self.currencyID == 1889 then
			local ci = C_CurrencyInfo.GetCurrencyInfo(self.currencyID)
			local q = ci and U.GetShiftedCurrencyValue(self.currencyID, ci.quantity) or "??"
			GameTooltip:AddLine("|n" .. (L"Current Progress: %s"):format("|cffffffff" .. q .. "|r"))
			GameTooltip:Show()
		end
	elseif self.achievementID then
		local self, achievementID, highlightAsset = GameTooltip, self.achievementID, self.assetID
		local _, n, _points, c, _, _, _, description, _, _icon, _, _, wasEarnedByMe, _earnedBy =
			GetAchievementInfo(achievementID)
		self:SetText(n)
		if not c or not wasEarnedByMe then
			self:AddLine(ACHIEVEMENT_TOOLTIP_IN_PROGRESS:format(UnitName("player")), 0.1, 0.9, 0.1)
			self:AddLine(" ")
		end
		self:AddLine(description, 1,1,1,1)
		local nc = GetAchievementNumCriteria(achievementID)
		for i=1,nc,2 do
			local n1, _, c1, _, _, _, _, asid = GetAchievementCriteriaInfo(achievementID, i)
			n1 = (asid == highlightAsset and "|cffffea00" or c1 and "|cff20c020" or "|cffa8a8a8") .. n1
			if i == nc then
				self:AddLine(n1)
			else
				local n2, _, c2, _, _, _, _, asid = GetAchievementCriteriaInfo(achievementID, i+1)
				n2 = (asid == highlightAsset and "|cffffea00" or c2 and "|cff20c020" or "|cffa8a8a8") .. n2
				self:AddDoubleLine(n1, n2)
			end
		end
	else
		GameTooltip:Hide()
		return
	end
	if self.ShowQuantityFromWidgetText and not showCurrencyBar then
		local w = self[self.ShowQuantityFromWidgetText]
		local t = w and w:GetText() or ""
		local c = NORMAL_FONT_COLOR
		if t ~= "" then
			GameTooltip:AddLine((L"Quantity: %s"):format("|cffffffff" .. t), c.r, c.g, c.b)
		end
	end
	GameTooltip:Show()
	if self.tooltipPostShow then
		self.tooltipPostShow(GameTooltip, self)
	end
	if showCurrencyBar then
		local q1, factionID, cur, max, label = self.currencyQ, C_CurrencyInfo.GetFactionGrantedByCurrency(self.currencyID)
		if factionID then
			if C_Reputation.IsFactionParagon(factionID) then
				label, cur, max = _G["FACTION_STANDING_LABEL8" .. (UnitSex("player") ~= 2 and "_FEMALE" or "")], C_Reputation.GetFactionParagonInfo(factionID)
				cur = cur % max
			else
				local _, _, stID, bMin, bMax, bVal  = GetFactionInfoByID(factionID)
				if stID and bMin then
					cur, max, label = bVal - bMin, bMax-bMin, _G["FACTION_STANDING_LABEL" .. stID .. (UnitSex("player") ~= 2 and "_FEMALE" or "")]
				end
			end
		end
		if not (cur and max) then
			return
		end
		label = label .. " - " .. BreakUpLargeNumbers(cur) .. " / " .. BreakUpLargeNumbers(max)
		CreateObject("SharedTooltipProgressBar"):Activate(GameTooltip, cur, max, label, self.isRetrospective and 0 or q1)
	end
end
local function CommonTooltip_DelayedRefresh_OnUpdate(self, elapsed)
	local tl = self.tooltipRefreshDelay - (elapsed or 0)
	if not GameTooltip:IsOwned(self) then
		self:SetScript("OnUpdate", nil)
		self.tooltipRefreshDelay = nil
	elseif tl > 0 then
		self.tooltipRefreshDelay = tl
	else
		self:SetScript("OnUpdate", nil)
		self.tooltipRefreshDelay = nil
		self:GetScript("OnEnter")(self)
	end
end
local function CommonLinkable_OnClick(self)
	if self.itemLink then
		HandleModifiedItemClick(self.itemLink)
	elseif not IsModifiedClick("CHATLINK") then
	elseif self.achievementID then
		ChatEdit_InsertLink(GetAchievementLink(self.achievementID))
	elseif self.itemID then
		local _, link = GetItemInfo(self.itemID)
		if link then
			ChatEdit_InsertLink(link)
		end
	elseif self.currencyID and self.currencyID ~= 0 then
		ChatEdit_InsertLink(C_CurrencyInfo.GetCurrencyLink(self.currencyID, self.currencyAmount or 0))
	end
end
local function MissionList_ScrollToward(self, obj)
	if obj:GetBottom() < self:GetBottom() then
		self:GetScript("OnMouseWheel")(self, -1)
	elseif obj:GetTop() > self:GetTop() then
		self:GetScript("OnMouseWheel")(self, 1)
	end
end
local function MissionList_SpawnMissionButton(arr, i)
	local prev = type(i) == "number" and rawget(arr, i-1)
	if type(prev) == "table" then
		local cf = CreateObject("MissionButton", prev:GetParent())
		arr[i] = cf
		cf:SetPoint("TOPLEFT", 292*(((i-1)%3)+1)-284, math.floor((i-1)/3) *- 195)
		return cf
	end
end
local function MissionButton_OnClick(self)
	local s = S[self]
	if IsModifiedClick("CHATLINK") and s.missionID then
		ChatEdit_InsertLink(C.GetMissionLink(s.missionID))
	else
		self:GetParent():GetParent():ScrollToward(self)
	end
end
local function MissionButton_OnProgressBarClick(self)
	local s = S[self:GetParent()]
	if s.missionID and s.completableAfter and s.completableAfter <= GetTime() then
		U.InitiateMissionCompletion(s.missionID)
	end
end
local function MissionButton_OnViewClick(self)
	U.ShowMission(S[self:GetParent()].missionID, self:GetParent():GetParent():GetParent():GetParent())
end
local function MissionButton_SetGroupPortraits(mb, g, isVeiled, altWidget)
	local hasGroup = g and next(g) ~= nil or false
	mb.Group:SetShown(hasGroup)
	altWidget:SetShown(not hasGroup)
	local s = S[mb.Group]
	local vc = isVeiled and 0.85 or 1
	for i=0, hasGroup and 4 or -1 do
		local f = g[i]
		local t = f and C_Garrison.GetFollowerPortraitIconID(f)
		local c = t and vc or 0.2
		s[i]:SetTexture(t or "Interface/Masks/CircleMask")
		s[i]:SetVertexColor(c, c, c)
		s[5+i]:SetVertexColor(vc, vc, vc)
	end
end
local function Progress_UpdateTimer(self)
	local now, endTime = GetTime(), self.endTime
	if endTime <= now then
		self.Fill:SetWidth(math.max(0.01, self:GetWidth()))
		self.Fill:SetTexCoord(0, 1, 0, 1)
		self:SetScript("OnUpdate", nil)
		if self.endText then
			self.Text:SetText(self.endText)
		end
		self:SetEnabled(not not self.endClick)
		self.endTime, self.duration, self.endText, self.nextUp = nil
	elseif (self.nextUp or now) <= now then
		local w, d = self:GetWidth(), self.duration
		local secsLeft, p = endTime-now-0.5, math.min(1, 1-(endTime-now)/d)
		self.Fill:SetWidth(math.max(0.01, w*p))
		self.Fill:SetTexCoord(0, math.max(1/128, p), 0, 1)
		self.nextUp = now + math.min(PROGRESS_MIN_STEP/w * d, 0.01 + secsLeft % (secsLeft < 100 and 1 or 60))
		if self.showTimeRemaining then
			self.Text:SetText(GetTimeStringFromSeconds(secsLeft, false, true))
		else
			self.Text:SetText("")
		end
		self:Disable()
	end
end
local function Progress_SetProgress(self, progress)
	progress = progress > 1 and 1 or progress
	self.Fill:SetWidth(math.max(0.01,self:GetWidth()*progress))
	self.Fill:SetTexCoord(0, math.max(1/128, progress), 0, 1)
	self.endTime, self.duration, self.endText, self.endClick, self.nextUp = nil
	self:SetScript("OnUpdate", nil)
end
local function Progress_SetTimer(self, endTime, duration, endText, endClick, showTimeRemaining)
	self.endTime, self.duration, self.endText, self.endClick, self.showTimeRemaining, self.nextUp = endTime, duration, endText, endClick == true or nil, showTimeRemaining == true or nil, nil
	self:SetScript("OnUpdate", Progress_UpdateTimer)
	Progress_UpdateTimer(self)
end
local function TooltipProgressBar_Update(self)
	local p = self:GetParent()
	local pt, sb, pw = p:GetTop(), self:GetBottom(), p:GetWidth()
	if pt and sb then
		p:SetHeight(pt-sb+8)
	end
	if pw then
		self:SetWidth(pw - 20)
	end
	self.Bar:SetProgress(self.pv)
	self.Fill2:SetWidth(self.Bar:GetWidth()*self.v2)
end
local function TooltipProgressBar_Activate(self, tip, cur, max, label, q1)
	if not (cur and max) then
		return
	end
	self.pv = cur/max
	self.v2 = math.max(0.00001, math.min(1-self.pv, (q1 or 0)/max))
	self.Bar.Text:SetText(label)
	self.Fill2:SetAtlas((cur+ (q1 or 0)) > max and "UI-Frame-Bar-Fill-Green" or "UI-Frame-Bar-Fill-Yellow")
	local tl = (q1 or 0)/max
	self.Fill2:SetTexCoord(tl, tl+self.v2, 0, 1)
	self.Fill2:SetShown((q1 or 0) > 0)
	self:SetParent(tip)
	tip:AddLine(("|TInterface/Minimap/PartyRaidBlipsV2:5:65:0:0:64:32:62:63:0:2|t "):rep(3))
	local lastLine = _G[tip:GetName() .. "TextLeft" .. (tip:NumLines()-1)]
	self:SetPoint("TOPLEFT", lastLine, "BOTTOMLEFT", 0, -2)
	self:Show()
	tip:Show()
	TooltipProgressBar_Update(self)
end
local function TooltipProgressBar_OnHide(self)
	self:Hide()
	self:SetParent(nil)
	self:ClearAllPoints()
end
local function CountdownText_OnUpdate(self)
	local now = GetTime()
	if now >= self.cdtTick then
		local cdTo = self.cdtTo
		local secsLeft = cdTo-now
		if secsLeft <= 0 then
			self.CDTDisplay:SetText(self.cdtRest)
			self:SetScript("OnUpdate", nil)
			self.cdtTick, self.cdtTo = nil
		else
			self.cdtTick = secsLeft < 120 and (now + secsLeft % 0.5 + 0.01) or (now + secsLeft % 60 + 0.01)
			self.CDTDisplay:SetText(self.cdtPrefix .. GetTimeStringFromSeconds(secsLeft, self.cdtShort, self.cdtRoundedUp) .. self.cdtSuffix .. self.cdtRest)
		end
	end
end
local function CountdownText_SetCountdown(self, prefix, expireAt, suffix, rest, isShort, isRoundUp)
	prefix, suffix, rest = prefix or "", suffix or "", rest or ""
	local now = GetTime()
	if not (expireAt and expireAt > now) then
		self.CDTDisplay:SetText(rest or "")
		self:SetScript("OnUpdate", nil)
	else
		self.cdtTick, self.cdtPrefix, self.cdtTo, self.cdtSuffix, self.cdtRest, self.cdtShort, self.cdtRoundedUp = now, prefix, expireAt, suffix, rest, isShort, isRoundUp == true
		self:SetScript("OnUpdate", CountdownText_OnUpdate)
		CountdownText_OnUpdate(self)
	end
end
local function ResizedButton_SetText(self, text)
	(self.Text or self):SetText(text)
	self:SetWidth((self.Text or self):GetStringWidth()+26)
end
local function ResourceButton_Update(self, _event, currencyID)
	if currencyID == self.currencyID then
		local ci = C_CurrencyInfo.GetCurrencyInfo(currencyID)
		local quant = ci and U.GetShiftedCurrencyValue(currencyID, ci.quantity)
		if quant then
			self.Text:SetText(BreakUpLargeNumbers(quant))
			self:SetWidth(self.Text:GetStringWidth()+26)
		end
		if GameTooltip:IsOwned(self) and GameTooltip:IsShown() then
			self:GetScript("OnEnter")(self)
		end
	end
end
local function ResourceButton_OnClick(self)
	if IsModifiedClick("CHATLINK") then
		ChatEdit_InsertLink(C_CurrencyInfo.GetCurrencyLink(self.currencyID, 42))
	end
end
local function SetRarityBorder(b, r, atlas)
	r = type(r) == "number" and r or 2
	local vc = (atlas or r >= 1) and 1 or 0.65
	b:SetAtlas(atlas
		or r <= 1 and "loottoast-itemborder-gold"
		or r == 2 and "loottoast-itemborder-green"
		or r == 3 and "loottoast-itemborder-blue"
		or r == 4 and "loottoast-itemborder-purple"
		or r == 9 and "loottoast-itemborder-gold"
		or "loottoast-itemborder-orange")
	b:SetDesaturated(r <= 1 and not atlas)
	b:SetVertexColor(vc, vc, vc)
end
local RewardButton_SetReward do
	local baseXPReward = {title=L"Follower XP", tooltip=L"Awarded even if the adventurers are defeated.", icon="Interface/Icons/XP_Icon", qualityAtlas="loottoast-itemborder-purple"}
	function RewardButton_SetReward(self, rew, isOvermax, pw)
		if rew == "xp" then
			baseXPReward.followerXP = isOvermax
			return RewardButton_SetReward(self, baseXPReward)
		end
		self:SetShown(not not rew)
		if not rew then
			return
		end
		local q, tooltipTitle, tooltipText, cq = rew.quantity, rew.title
		if rew.icon then
			self.Icon:SetTexture(rew.icon)
		elseif rew.itemID then
			self.Icon:SetTexture(GetItemIcon(rew.itemID))
		end
		self.RarityBorder:SetDesaturated(false)
		self.RarityBorder:SetVertexColor(1,1,1)
		if rew.currencyID then
			if rew.currencyID == 0 then
				q = math.floor(rew.quantity / 1e4)
				tooltipText = GetMoneyString(rew.quantity)
				SetRarityBorder(self.RarityBorder, 9)
			else
				local ci = C_CurrencyInfo.GetCurrencyContainerInfo(rew.currencyID, rew.quantity)
				if ci then
					self.Icon:SetTexture(ci.icon)
					tooltipTitle = (ci.quality and "|c" .. (select(4,GetItemQualityColor(ci.quality)) or "ff00ffff") or "") .. ci.name
					tooltipText = NORMAL_FONT_COLOR_CODE .. (ci.description or "")
				end
				local ci2 = C_CurrencyInfo.GetCurrencyInfo(rew.currencyID)
				SetRarityBorder(self.RarityBorder, ci and ci.quality or ci2 and ci2.quality)
				cq = (isOvermax and pw and pw.currencyID == rew.currencyID and pw.currencyQ or 0) + q
			end
		elseif rew.itemID then
			q = rew.quantity == 1 and "" or rew.quantity or ""
			local r = select(3,GetItemInfo(rew.itemLink or rew.itemID)) or select(3,GetItemInfo(rew.itemID)) or 2
			SetRarityBorder(self.RarityBorder, r)
		elseif rew.followerXP then
			q, tooltipTitle, tooltipText = BreakUpLargeNumbers(rew.followerXP), rew.title, rew.tooltip
			SetRarityBorder(self.RarityBorder, 2, rew.qualityAtlas)
		end
		self.currencyID, self.currencyAmount, self.currencyQ = rew.currencyID, rew.quantity, cq
		self.itemID, self.itemLink = rew.itemID, rew.itemLink
		self.tooltipHeader, self.tooltipText = tooltipTitle, tooltipText
		self.Quantity:SetText(q == 1 and "" or q or "")
	end
end
local function RewardBlock_SetRewards(self, xp, rw)
	local nc = xp and (self[1]:SetReward("xp", xp) and nil or 2) or 1
	nc = nc + (self[nc]:SetReward(rw and rw[1]) and nil or 1)
	nc = nc + (self[nc]:SetReward(rw and rw[2]) and nil or 1)
	for i=nc, #self do self[i]:SetReward() end
	if self.Container then
		self.Container:SetWidth((self[1]:GetWidth()+4)*((xp and 1 or 0) + (rw and #rw or 0))-2)
	elseif self.Label then
		self[1]:GetParent():SetWidth(self.Label:GetStringWidth()+16+32*(1+(rw and #rw or 0)))
	end
end
local function FollowerButton_OnDragStart(self)
	if self:IsEnabled() then
		local fa = CovenantMissionFrame.MissionTab.MissionPage.Board.framesByBoardIndex
		local fid = self.info.followerID
		if not self.info.isAutoTroop then
			for i=0,4 do
				local f = fa[i]
				if f:IsShown() and f:GetFollowerGUID() == fid then
					return
				end
			end
		end
		CovenantMissionFrame:OnDragStartFollowerButton(CovenantMissionFrame:GetPlacerFrame(), self, 24);
	end
end
local function FollowerButton_OnDragStop(self)
	if self:IsEnabled() then
		CovenantMissionFrame:OnDragStopFollowerButton(CovenantMissionFrame:GetPlacerFrame());
	end
end
local function GetAltModifierKeyText(ex)
	local m = GetModifiedClick(ex)
	return m and m:match("ALT") and CTRL_KEY_TEXT or ALT_KEY_TEXT
end
local function IsAltModifiedClick(ex)
	local m = GetModifiedClick(ex)
	if m and m:match("ALT") then
		return IsControlKeyDown()
	else
		return IsAltKeyDown()
	end
end
local function FollowerButton_OnClick(self, b)
	if b == "LeftButton" and not self.info.isAutoTroop and IsAltModifiedClick("CHATLINK") then
		local gid = self.info.garrFollowerID
		U.FollowerSetFavorite(gid, not U.FollowerIsFavorite(gid))
		GameTooltip:Hide()
		self:GetParent():Refresh()
		return
	elseif b == "RightButton" then
		local fa = CovenantMissionFrame.MissionTab.MissionPage.Board.framesByBoardIndex
		local fid = self.info.followerID
		for i=0,self.info.isAutoTroop and -1 or 4 do
			if fa[i]:GetFollowerGUID() == fid then
				CovenantMissionFrame:RemoveFollowerFromMission(fa[i], true)
				return
			end
		end
		CovenantMissionFrame.MissionTab.MissionPage:AddFollower(fid)
	elseif b == "LeftButton" and IsModifiedClick("CHATLINK") then
		ChatEdit_InsertLink(C.GetFollowerLink(self.info.followerID))
	end
	self:GetParent():SyncToBoard()
end
local function FollowerButton_OnEnter(self)
	local info = self.info
	if not info then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	U.SetFollowerInfo(GameTooltip, info, info.autoCombatSpells, nil, nil, nil, nil, true)
	local tmid = U.FollowerHasTentativeGroup(info.followerID)
	if info.status == GARRISON_FOLLOWER_ON_MISSION and info.missionTimeEnd then
		local tl = math.max(0, info.missionTimeEnd-GetTime())
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(tl > 0 and COVENANT_MISSIONS_ON_ADVENTURE_DURATION:format(GetTimeStringFromSeconds(tl, false, true, true)) or COVENANT_FOLLOWER_MISSION_COMPLETE, 1, 0.4, 0)
		GameTooltip:Show()
	elseif tmid and C_Garrison.GetMissionTimes(tmid) then
		local tn = C_Garrison.GetMissionName(tmid)
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine((L"In Tentative Party - %s"):format(tn or "??"), 1, 0.4, 0)
		GameTooltip:Show()
	end
	if not (info.isAutoTroop or info.missionTimeEnd) then
		local act = U.FollowerIsFavorite(info.garrFollowerID) and BATTLE_PET_UNFAVORITE or BATTLE_PET_FAVORITE
		local short = GetAltModifierKeyText("CHATLINK") .. "+|TInterface\\TUTORIALFRAME\\UI-TUTORIAL-FRAME:0:0:0:-1:512:512:2:78:240:316|t: "
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(short .. act, 0.5, 0.8, 1)
		GameTooltip:Show()
	end
end
local function FollowerButton_GetInfo(self)
	return self.info
end
local function FollowerButton_GetFollowerGUID(self)
	return self.info.followerID
end
local function FollowerButton_SetInfo(self, info)
	local s = S[self]
	local onMission = info.status == GARRISON_FOLLOWER_ON_MISSION
	local inTG = not info.isAutoTroop and U.FollowerHasTentativeGroup(info.followerID)
	local vc, dc = inTG and 0.55 or onMission and 0.25 or 1, onMission and 0.65 or 1
	local mc = onMission and DISABLED_FONT_COLOR or NORMAL_FONT_COLOR
	local mtl = info.missionTimeEnd and GetTimeStringFromSeconds(math.max(0, info.missionTimeEnd-GetTime()), 2, true, true) or ""
	self.info = info
	s.Portrait:SetTexture(info.portraitIconID)
	s.Portrait2:SetTexture(info.portraitIconID)
	s.TextLabel:SetText(onMission and mtl or info.level)
	s.TextLabel:SetTextColor(mc.r, mc.g, mc.b)
	s.PortraitR:SetVertexColor(dc, dc, dc)
	s.PortraitT:SetShown(inTG)
	s.Portrait:SetVertexColor(vc, vc, vc)
	s.Portrait2:SetShown(inTG or onMission)
	s.Favorite:SetShown(not info.isAutoTroop and not (onMission and inTG) and (info.soFavorite or 0) > 0)
	if inTG then
		s.Portrait2:SetVertexColor(0.6, 0, 0)
	else
		s.Portrait2:SetVertexColor(1, 1, 1)
	end
	local ir = info.role
	s.Role:SetAtlas(ir == 1 and "adventures-dps" or ir == 4 and "adventures-healer" or ir == 5 and "adventures-tank" or "adventures-dps-ranged")
	self:SetEnabled(not onMission)
	s.Health:SetShown(not onMission)
	local cs = info.autoCombatantStats
	s.Health:SetWidth(s.HealthBG:GetWidth()*math.min(1, cs and (cs.currentHealth/cs.maxHealth)+0.001 or 0.001))
	s.ExtraTex:SetDesaturated(onMission)
	if info.missionTimeEnd then
		local t = GetTime()
		local tl = info.missionTimeEnd-t
		local te = tl > 1 and (t+tl%60+0.05)
		if te and te < (self:GetParent().nextUpdate or 0) then
			self:GetParent().nextUpdate = te
		end
	end
	local ns = info.autoCombatSpells and #info.autoCombatSpells or 0
	for i=1,ns do
		local sp = info.autoCombatSpells[i]
		s.Abilities[i]:SetTexture(sp.icon)
		s.Abilities[i]:Show()
		s.AbilitiesB[i]:Show()
	end
	for i=ns+1, #s.Abilities do
		s.Abilities[i]:Hide()
		s.AbilitiesB[i]:Hide()
	end
	if onMission then
		s.HealthBG:SetGradient("VERTICAL", 0.1,0.1,0.1, 0.2,0.2, 0.2)
	else
		s.HealthBG:SetGradient("VERTICAL", 0.07,0.07,0.07, 0.14,0.14,0.14)
	end
end
local SortFollowerList, CompareFollowerXP do
	local preferLowHealth, uiOrder
	local function FollowerList_Compare(a,b)
		local ac, bc = a.missionTimeEnd, b.missionTimeEnd
		if ac ~= bc then
			if ac and bc then
				return ac < bc
			else
				return not ac
			end
		end
		ac, bc = not a.inTentativeGroup, not b.inTentativeGroup
		if ac ~= bc then
			return ac
		end
		local uiFree = uiOrder and not (a.missionTimeEnd or a.inTentativeGroup)
		if uiFree and a.soFavorite ~= b.soFavorite then
			ac, bc = a.soFavorite, b.soFavorite
		else
			ac, bc = a.level, b.level
		end
		if preferLowHealth and ac == bc then
			ac, bc = a.autoCombatantStats, b.autoCombatantStats
			ac, bc = ac and -ac.currentHealth/ac.maxHealth or 0, bc and -bc.currentHealth/bc.maxHealth or 0
		end
		if uiFree and ac == bc then
			ac, bc = #(a.autoCombatSpells or "1"), #(b.autoCombatSpells or "1")
		end
		if ac == bc then
			ac, bc = a.xp, b.xp
		end
		if ac == bc then
			ac, bc = a.autoCombatantStats, b.autoCombatantStats
			ac, bc = ac and ac.maxHealth or 0, bc and bc.maxHealth or 0
		end
		if ac == bc then
			ac, bc = b.name, a.name
		end
		return ac > bc
	end
	function CompareFollowerXP(a,b)
		local ac, bc = a.level, b.level
		if ac == bc then
			ac, bc = a.xp, b.xp
		end
		if ac == bc then
			ac, bc = a.name, b.name
		end
		return ac > bc
	end
	function SortFollowerList(list, preferLowHP, forUI)
		preferLowHealth, uiOrder = preferLowHP, forUI
		for i=1,#list do
			list[i].inTentativeGroup = U.FollowerHasTentativeGroup(list[i].followerID)
			list[i].soFavorite = forUI and U.FollowerIsFavorite(list[i].garrFollowerID) and 1 or 0
		end
		table.sort(list, FollowerList_Compare)
	end
end
local function FollowerList_GetTroopHint(ft)
	local o
	if #ft > 0 then
		table.sort(ft, CompareFollowerXP)
		local m = (#ft + #ft%2)/2
		local ml = ft[m].level
		if #ft % 2 == 0 then
			local fi = ft[m+1]
			o = "|cffa0a0a0[" .. fi.level .. "]|r |cffffffff" .. fi.name .. "|r"
			ml = (ml+fi.level)/2
		end
		for i=ft[m].level == 60 and 0 or m, 1, -1 do
			local fi = ft[i]
			o = "|cffa0a0a0[" .. fi.level .. "]|r |cffffffff" .. fi.name .. "|r" .. (o and "\n" .. o or "")
			if i == 1 or ft[i].level ~= ft[i-1].level then
				break
			end
		end
		local mlc = ("%s%.3g|r"):format(NORMAL_FONT_COLOR_CODE, ml)
		o = (L"Your troop level is the median level of your companions (%s), rounded down. It does not decrease when you recruit additional companions."):format(mlc)
		    .. (ml < 60 and "\n\n" .. NORMAL_FONT_COLOR_CODE .. L"These companions currently affect your troop level:" .. "|r\n" .. o or "")
	end
	return COVENANT_MISSIONS_TUTORIAL_TROOPS .. (o and ("\n\n" .. o) or "")
end
local function FollowerList_SyncToBoard(self)
	local fa = CovenantMissionFrame.MissionTab.MissionPage.Board.framesByBoardIndex
	local ca = S[self].companions
	for i=1, #ca do
		local c = ca[i]
		local isInMission = false
		for i=0, c:IsShown() and 4 or -1 do
			local f = fa[i]
			if f and f.name and f:IsShown() and f.info and f.info.followerID == c.info.followerID then
				isInMission = true
				break
			end
		end
		if S[c].EC then
			S[c].EC:SetShown(isInMission)
		end
	end
end
local function FollowerList_SyncXPGain(self, setXPGain)
	local ca = S[self].companions
	local xpGain = type(setXPGain) == "number" and setXPGain or self.xpGain or -1
	self.xpGain = xpGain
	for i=1,#ca do
		local w = ca[i]
		local info = w.info
		local isAway = (info and info.status == GARRISON_FOLLOWER_ON_MISSION)
		local willLevel = (info and not info.isAutoTroop and not info.isMaxLevel and info.xp and info.levelXP and (info.levelXP-info.xp) <= xpGain)
		S[w].Blip:SetShown(willLevel and not isAway)
	end
end
local function FollowerList_Refresh(self, setXPGain)
	local s = S[self]
	local wt, wf = s.troops, s.companions
	if self.noRefresh == nil then
		local fl = C_Garrison.GetFollowers(123)
		local ft = C_Garrison.GetAutoTroops(123)
		for i=1,#ft do
			FollowerButton_SetInfo(wt[i], AugmentFollowerInfo(ft[i]))
		end
		for i=1,#fl do
			AugmentFollowerInfo(fl[i])
		end
		s.TroopInfo.tooltipText = FollowerList_GetTroopHint(fl)
		SortFollowerList(fl, false, true)
		for i=1,#fl do
			local fi = fl[i]
			FollowerButton_SetInfo(wf[i], fi)
			wf[i]:Show()
		end
		for i=#fl+1,#wf do
			wf[i]:Hide()
		end
		self:SetHeight(135+72*math.ceil(#fl/4))
		self.noRefresh = true
	end
	FollowerList_SyncToBoard(self)
	FollowerList_SyncXPGain(self, setXPGain)
end
local function FollowerList_OnUpdate(self)
	local t = GetTime()
	self.noRefresh = nil
	if t >= (self.nextUpdate or 0) then
		self.nextUpdate = t+60
		self:Refresh()
		local mf = GetMouseFocus()
		if mf and mf:GetParent() == self and GameTooltip:IsOwned(mf) then
			local f = mf:GetScript("OnEnter")
			if f then f(mf) end
		end
	end
end
local function DoomRun_OnEnter(self)
	local ft, g, gn = C_Garrison.GetFollowers(123), {}, 0
	SortFollowerList(ft, true, false)
	for i=#ft,1,-1 do
		local fi = ft[i]
		if fi.isCollected and not fi.isMaxLevel and fi.status ~= GARRISON_FOLLOWER_ON_MISSION
		   and not U.FollowerHasTentativeGroup(fi.followerID)
		   and C_Garrison.GetFollowerAutoCombatStats(fi.followerID).currentHealth > 0 then
			g[gn], gn = i, gn + 1
			if gn == 5 then
				break
			end
		end
	end
	local xpR = S[self:GetParent()].baseXPReward
	local xpT = "|cff00ff00" .. GARRISON_REWARD_XP_FORMAT:format(BreakUpLargeNumbers(xpR)) .. "|r"
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText(L"Doomed Run")
	GameTooltip:AddLine(L("Failing this mission grants %s to each companion."):format(xpT), 1,1,1,1)
	if gn > 0 then
		GameTooltip:AddLine(" ")
		for i=0, gn-1 do
			local fi = ft[g[i]]
			local willLevelUp = fi.levelXP and fi.xp and fi.levelXP - fi.xp <= xpR or false
			local upTex = willLevelUp and " |A:bags-greenarrow:0:0|a" or ""
			GameTooltip:AddLine("|cffa0a0a0[" .. fi.level .. "]|r " .. fi.name .. upTex, 1,1,1)
			g[i] = fi.followerID
		end
		GameTooltip:AddLine(L"Tentatively assign these rookies to this adventure.", 0.2,1,0.2, 1)
		GameTooltip:AddLine("|TInterface/TUTORIALFRAME/UI-TUTORIAL-FRAME:14:12:0:-1:512:512:10:70:330:410|t " .. L"Start the adventure", 0.5, 0.8, 1)
	end
	self.group = gn > 0 and g or nil
	GameTooltip:Show()
end
local function DoomRun_OnClick(self, button)
	local mid = S[self:GetParent()].missionID
	local g, st = self.group, self.showTime
	local inShowCooldown = (GetTime()-st < 0.25)
	if not (mid and g and st) or inShowCooldown then return end
	if GameTooltip:IsOwned(self) then
		GameTooltip:Hide()
	end
	if button == "RightButton" then
		U.StartMissionWithDelay(mid, g)
	else
		U.StoreMissionGroup(mid, g)
		PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
	end
	EV("I_MISSION_LIST_UPDATE")
end
local function DoomRun_OnShow(self)
	self.showTime = GetTime()
end
local function TentativeGroupClear_OnClick(self)
	local mid = S[self:GetParent()].missionID
	U.StoreMissionGroup(mid, nil)
	PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
end
local function getWastedRewards(r)
	local o
	for i=1, r and #r or 0 do
		local ri = r[i]
		local cid = ri and ri.currencyID
		if cid and cid ~= 0 and ri.quantity then
			local ci = C_CurrencyInfo.GetCurrencyInfo(cid)
			local wq = ci and (ci.maxQuantity or 0) > 0 and ci.quantity and math.min(ci.quantity, ci.quantity + ri.quantity - ci.maxQuantity) or 0
			if wq > 0 then
				o = (o and o .. "   " or "") .. wq .. " |T" .. (ci.iconFileID or "Interface/Icons/Temp") .. ":0|t"
			end
		end
	end
	return o
end
local function UButton_SetStartMode(self)
	local tco = 0
	for mid, nt in U.EnumerateTentativeGroups() do
		tco = tco + nt + (C_Garrison.GetMissionCost(mid) or 0)
	end
	local anima = C_CurrencyInfo.GetCurrencyInfo(1813)
	self.mode = anima and anima.quantity and anima.quantity >= tco and "start-send" or "start-cost"
end
local function UButton_Sync(self)
	local ps = S[self:GetParent()]
	if self == ps.StartButton then
		return UButton_Sync(ps.UnButton)
	end
	local idm = U.HasDelayedStartMissions()
	local ism = U.IsStartingMissions()
	local icm = U.IsCompletingMissions()
	local tg = U.HaveTentativeGroups()
	self:Show()
	if ism then
		self:SetFormattedText(L"%d |4party:parties; remaining...", ism)
		self.mode = "stop-send"
	elseif idm then
		self:SetFormattedText(L"Starting soon...")
		self.mode = "stop-delayed-send"
	elseif icm then
		self:SetFormattedText(L"%d |4adventure:adventures; remaining...", icm)
		self.mode = "stop-complete"
	elseif ps and ps.hasCompletedMissions then
		self:SetText(L"Complete All")
		self.mode = "start-complete"
	elseif tg then
		self:SetText(L"Send Tentative Parties")
		UButton_SetStartMode(self)
	else
		self.mode, self.clickWithEscape = nil, nil
		self:Hide()
	end
	local ocwe = self.clickWithEscape
	self.clickKey = self.mode ~= "start-send" and "SPACE" or nil
	self.clickWithEscape = self.mode and self.mode:match("^stop%-") and true or nil
	self.eatEscapeUntil = math.max(self.eatEscapeUntil or -math.huge, ocwe and self.clickWithEscape ~= ocwe and GetTime()+0.5 or -math.huge)
	self.Glow:SetShown(self.mode == "stop-delayed-send")
	if GameTooltip:IsOwned(self) then
		local oe = self:GetScript("OnEnter")
		if not self:IsVisible() then
			GameTooltip:Hide()
		elseif oe then
			oe(self)
		end
	end
	if self.mode == "start-complete" and tg then
		UButton_SetStartMode(ps.StartButton)
		ps.StartButton:Show()
	else
		ps.StartButton:Hide()
	end
end
local function UButton_OnEnter(self)
	local m = self.mode
	if m == "start-send" or m == "stop-send" or m == "start-cost" then
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine(L"Send Tentative Parties")
		local cb = C_CurrencyInfo.GetBasicCurrencyInfo(1813)
		local curIco = cb and cb.icon and " |T" .. cb.icon .. ":0|t" or ""
		local hadZH, hourglass = false, "|Tinterface/common/mini-hourglass:0:0:0:0:1:1:0:1:0:1:255:80:0|t "
		local tco, ng = 0,0
		for mid, nt, zeroHealth in U.EnumerateTentativeGroups() do
			local co = C_Garrison.GetMissionCost(mid) or 0
			hadZH = hadZH or zeroHealth
			GameTooltip:AddDoubleLine((zeroHealth and hourglass or "") .. C_Garrison.GetMissionName(mid), (co+nt) .. curIco, 1,1,1, 1,1,1)
			tco, ng = tco + co + nt, ng + 1
		end
		if ng > 1 then
			local nc, ac = NORMAL_FONT_COLOR, m == "start-cost" and RED_FONT_COLOR or HIGHLIGHT_FONT_COLOR
			GameTooltip:AddDoubleLine(TOTAL, tco .. curIco, nc.r, nc.g, nc.b, ac.r, ac.g, ac.b)
		end
		GameTooltip:AddLine(" ")
		if m == "start-cost" then
			GameTooltip:AddLine(L"Insufficient anima", 1, 0.5, 0)
		end
		if hadZH then
			GameTooltip:AddLine(hourglass .. "|cffff8000" .. COVENANT_MISSIONS_COMPANIONS_MISSING_HEALTH, 1, 0.5, 0)
			self.tooltipRefreshDelay = 10
			self:SetScript("OnUpdate", CommonTooltip_DelayedRefresh_OnUpdate)
		end
		GameTooltip:AddLine("|TInterface/TUTORIALFRAME/UI-TUTORIAL-FRAME:14:12:0:-1:512:512:10:70:330:410|t " .. L"Clear all tentative parties", 0.5, 0.8, 1)
		GameTooltip:Show()
	elseif m == "start-complete" then
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine(L"Complete All")
		local ct = C_Garrison.GetCompleteMissions(123)
		for i=1, ct and #ct or 0 do
			local m = ct[i]
			GameTooltip:AddDoubleLine(m.name or "", getWastedRewards(m.rewards) or "", 1,1,1, 1,0,0)
		end
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("|TInterface/TUTORIALFRAME/UI-TUTORIAL-FRAME:14:12:0:-1:512:512:10:70:330:410|t " .. COVENANT_MISSIONS_COMBAT_LOG_HEADER, 0.5, 0.8, 1)
		GameTooltip:Show()
	elseif m == "stop-delayed-send" then
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine(L"Starting soon...")
		local cb = C_CurrencyInfo.GetBasicCurrencyInfo(1813)
		local curIco = cb and cb.icon and " |T" .. cb.icon .. ":0|t" or ""
		for mid, nt in U.EnumerateTentativeGroups() do
			if U.IsMissionStartingSoon(mid) then
				local co = C_Garrison.GetMissionCost(mid) or 0
				GameTooltip:AddDoubleLine(C_Garrison.GetMissionName(mid), (co+nt) .. curIco, 1,1,1, 1,1,1)
			end
		end
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("|TInterface/TUTORIALFRAME/UI-TUTORIAL-FRAME:14:12:0:-1:512:512:10:70:330:410|t " .. COVENANT_MISSIONS_START_ADVENTURE, 0.5, 0.8, 1)
		GameTooltip:Show()
	end
end
local function UButton_OnClick(self, button)
	local m, snd = self.mode, SOUNDKIT.U_CHAT_SCROLL_BUTTON
	if U.IsStartingMissions() and m == "stop-send" then
		U.StopStartingMissions()
	elseif U.IsCompletingMissions() and m == "stop-complete" then
		U.StopCompletingMissions()
	elseif m == "stop-delayed-send" then
		if button == "RightButton" then
			U.RushDelayedStartMissions()
		else
			U.ClearDelayedStartMissions()
			U.StopStartingMissions()
			snd = 39514
		end
	elseif m == "start-complete" then
		if button == "RightButton" then
			U.InitiateMissionCompletion("first")
		else
			U.StartCompletingMissions()
			if GameTooltip:IsOwned(self) then
				GameTooltip:Hide()
			end
		end
	elseif U.HaveTentativeGroups() and m == "start-send" then
		if button == "RightButton" then
			U.DisbandTentativeGroups()
		else
			U.SendTentativeGroups()
		end
	end
	PlaySound(snd)
	UButton_Sync(self)
end
local function UButton_OnKeyDown(self, button)
	if self:GetParent().keyFocus then
		return
	end
	local click = button and button == self.clickKey
	local abort = button == "ESCAPE" and self.clickWithEscape
	local eatEsc = button == "ESCAPE" and self.eatEscapeUntil and self.eatEscapeUntil >= GetTime()
	self:SetPropagateKeyboardInput(not (click or abort or eatEsc))
	if click or abort then
		self:Click()
	end
end
local function Toast_Animate(self, elapsed)
	local now, as, ap, d = GetTime(), self.animStart, self.animPhase
	if as and elapsed > 0.04 then
		as = as + elapsed - 0.04
		self.animStart = as
	end
	if ap == nil then
		self.animPhase, self.animStart = 1, nil
		self:SetAlpha(0)
		return
	elseif as == nil then
		self.animStart, as = now, now
		self:SetAlpha(1)
	end
	d = now-as
	if d < 0.5 then
		self.PreGlow:SetAlpha(d < 0.25 and (d < 0.125 and d*8 or 2-d*8)*0.75 or 0)
		self.Background:SetAlpha(d < 0.15 and sin(20+70*d/0.15) or 1)
		self.Sheen:SetAlpha(sin(360*d))
		self.Sheen:SetPoint("LEFT", 480*d, -1)
	elseif d >= 4 then
		self:Hide()
	elseif self:IsMouseOver() then
		self.animStart = now-2
		if ap ~= 2 then
			self.animPhase = 2
			self.PreGlow:SetAlpha(0)
			self.Background:SetAlpha(1)
			self.Sheen:SetAlpha(0)
			self:SetAlpha(1)
		end
	elseif d >= 3 then
		self:SetAlpha(cos(90*(d-3)))
		self.animPhase = 3
	elseif ap ~= 2 then
		self.animPhase = 2
		self.PreGlow:SetAlpha(0)
		self.Background:SetAlpha(1)
		self.Sheen:SetAlpha(0)
	end
end
local function Toast_OnClick(self, button)
	if button == "RightButton" then
		self.animPhase, self.animStart = nil
		self:Hide()
	end
end
local function MissionPage_AcquireToast(self, followerMode)
	local toasts, toast = self.Toasts
	for i=1,#toasts do
		toast = toasts[i]
		if not toast:IsShown() then
			break
		end
		toast = nil
	end
	if not toast then
		toast = CreateObject("MissionToast", toasts[1]:GetParent())
		toast:SetPoint("TOP", toasts[#toasts], "BOTTOM", 0, -5)
		toasts[#toasts+1] = toast
	end
	followerMode = not not followerMode
	S[toast].Rewards.Container:SetWidth(38)
	S[toast].Rewards.Container:SetShown(not followerMode)
	toast.Portrait:SetShown(followerMode)
	toast.PortraitFrame:SetShown(followerMode)
	toast.animStart, toast.animPhase = nil
	toast:Show()
	return toast
end
local function MissionToast_CheckTooltip(tip, self)
	if (tip:GetLeft() or 2) < 1 then
		tip:ClearAllPoints()
		tip:SetPoint("LEFT", self, "RIGHT", self.tooltipFXO or 0, self.tooltipFYO or 0)
	end
end
local function cmpTimeLeft(a, b)
	if a.timeLeft ~= b.timeLeft then
		return a.timeLeft < b.timeLeft
	end
	return (a.name or "") < (b.name or "")
end
local function Common_RefreshTooltip(self)
	local rat = self.refreshAt
	local owned = rat and GameTooltip:IsOwned(self)
	if owned and rat > GetTime() then
		return
	end
	self.refreshAt = nil
	self:SetScript("OnUpdate", nil)
	if owned then
		self:GetScript("OnEnter")(self)
	end
end
local function AwayFollowers_OnEnter(self)
	GameTooltip:SetOwner(self, self.tooltipAnchor or "ANCHOR_TOP", self.tooltipXO or 0, self.tooltipYO or 0)
	GameTooltip:SetText(ITEM_QUALITY_COLORS[3].hex .. COVENANT_MISSION_FOLLOWER_CATEGORY)
	local ft, ct, nt = {}, C_Garrison.GetFollowers(123), 0
	for i=1,#ct do
		local ci = ct[i]
		if ci.status == GARRISON_FOLLOWER_ON_MISSION then
			ci.timeLeft = C_Garrison.GetFollowerMissionTimeLeftSeconds(ci.followerID) or 86400
			ft[#ft+1] = ci
		elseif U.FollowerHasTentativeGroup(ci.followerID) then
			nt = nt + 1
		end
	end
	table.sort(ft, cmpTimeLeft)
	local refNext = nil
	if #ft == 0 and nt == 0 then
		GameTooltip:AddLine(L'All companions are ready for adventures.', 1,1,1);
	elseif #ct ~= #ft or nt > 0 then
		GameTooltip:AddLine((L'%d |4companion is:companions are; ready for adventures.'):format(#ct-#ft), 1,1,1, 1)
	end
	if nt > 0 then
		GameTooltip:AddLine((L'%d |4companion is:companions are; in a tentative party.'):format(nt), 1,1,1, 1)
	end
	if #ft > 0 then
		if GameTooltip:NumLines() > 1 then
			GameTooltip:AddLine(" ")
		end
		GameTooltip:AddLine(L"Returning soon:")
		for i=1,#ft do
			local fi = ft[i]
			local nr, tl = (fi.timeLeft + 59.998) % 60, U.GetTimeStringFromSeconds(fi.timeLeft, false, true, true)
			refNext = refNext and refNext <= nr and refNext or nr
			GameTooltip:AddDoubleLine("|cff909090[" .. fi.level .. "]|r|cffffffff " .. fi.name, NORMAL_FONT_COLOR_CODE .. " " .. (tl or ""))
		end
	end
	self.refreshAt = refNext and (GetTime() + refNext)
	self:SetScript("OnUpdate", Common_RefreshTooltip)
	GameTooltip:Show()
end

do -- Factory.ObjectGroup
	local NamedMethodCallCache = setmetatable({}, {__index=function(t,k)
		t[k] = function(self, ...)
			for i=1,#self do
				local o = self[i]
				securecall(o[k], o, ...)
			end
		end
		return t[k]
	end})
	local ObjectGroup_Meta = {__index=function(t,k)
		if type(k) == "string" and type(t[1]) == "table" and type(t[1][k]) == "function" then
			t[k] = NamedMethodCallCache[k]
			return t[k]
		end
	end}
	function Factory.ObjectGroup(...)
		return setmetatable(type((...)) == "table" and ... or {...}, ObjectGroup_Meta)
	end
end

function Factory.PanelButton(parent)
	local r = CreateFrame("Button", nil, parent, "UIPanelButtonNoTooltipTemplate")
	r:SetHeight(UIBUTTON_HEIGHT)
	r:SetPushedTextOffset(-1, -1)
	return r
end
function Factory.PanelButtonGlow(p)
	local ex, ey, w = 6, 6, 16
	local g = CreateFrame("Frame", nil, p)
	g:SetFlattensRenderLayers(true)
	local t = g:CreateTexture(nil, "BACKGROUND", nil, -1)
	g:SetAllPoints()
	t:SetTexture("Interface/Buttons/UI-Panel-Button-Glow")
	t:SetPoint("TOPLEFT", -ex, ey)
	t:SetPoint("BOTTOMRIGHT", g, "BOTTOMLEFT", w-ex, -ey)
	t:SetTexCoord(0, 20/128, 0, 38/64)
	t:SetBlendMode("ADD")
	t, g[1] = g:CreateTexture(nil, "BACKGROUND", nil, -1)
	t:SetTexture("Interface/Buttons/UI-Panel-Button-Glow")
	t:SetPoint("TOPRIGHT", ex, ey)
	t:SetPoint("BOTTOMLEFT", g, "BOTTOMRIGHT", ex-w, -ey)
	t:SetTexCoord(75/128, 95/128, 0, 38/64)
	t:SetBlendMode("ADD")
	t, g[2] = g:CreateTexture(nil, "BACKGROUND", nil, -1)
	t:SetTexture("Interface/Buttons/UI-Panel-Button-Glow")
	t:SetPoint("TOPLEFT", w-ex, ey)
	t:SetPoint("BOTTOMRIGHT", ex-w, -ey)
	t:SetTexCoord(20/128, 75/128, 0, 38/64)
	t:SetBlendMode("ADD")
	g[3] = t
	local ag = g:CreateAnimationGroup()
	ag:SetLooping("BOUNCE")
	local aa = ag:CreateAnimation("Alpha")
	aa:SetFromAlpha(0.15)
	aa:SetToAlpha(0.75)
	aa:SetDuration(0.8)
	aa:SetSmoothing("IN_OUT")
	ag:Play()
	return g
end
function Factory.RaisedBorder(parent)
	local border = CreateFrame("Frame", nil, parent)
	border:SetPoint("TOPLEFT", 0, 8)
	border:SetPoint("BOTTOMRIGHT", 0, -4)
	do
		local t = border:CreateTexture(nil, "BACKGROUND")
		t:SetPoint("TOPLEFT", 0, 2)
		t:SetPoint("TOPRIGHT", 0, 2)
		t:SetHeight(12)
		t:SetTexture("Interface/Garrison/AdventureMissionsFrameHorizontal")
		t:SetTexCoord(0,1, 67/128, 79/128)
		t = border:CreateTexture(nil, "BACKGROUND")
		t:SetPoint("BOTTOMLEFT", 0, -2)
		t:SetPoint("BOTTOMRIGHT", 0, -2)
		t:SetHeight(12)
		t:SetTexture("Interface/Garrison/AdventureMissionsFrameHorizontal")
		t:SetTexCoord(0,1, 79/128, 67/128)
		t = border:CreateTexture(nil, "BACKGROUND")
		t:SetPoint("TOPLEFT", -1, 0)
		t:SetPoint("BOTTOMLEFT", -1, 0)
		t:SetWidth(12)
		t:SetTexture("Interface/Garrison/AdventureMissionsFrameVert")
		t:SetTexCoord(85/128, 97/128, 0, 1)
		t = border:CreateTexture(nil, "BACKGROUND")
		t:SetPoint("TOPRIGHT", 1, 0)
		t:SetPoint("BOTTOMRIGHT", 1, 0)
		t:SetWidth(12)
		t:SetTexture("Interface/Garrison/AdventureMissionsFrameVert")
		t:SetTexCoord(67/128, 79/128, 0, 1)
		t = border:CreateTexture(nil, "BACKGROUND", nil, 1)
		t:SetSize(42, 42)
		t:SetPoint("TOPLEFT")
		t:SetTexture("Interface/Garrison/AdventureMissionsFrame")
		t:SetTexCoord(650/1024, 688/1024, 1119/2048, 1158/2048)
		t = border:CreateTexture(nil, "BACKGROUND", nil, 1)
		t:SetSize(42, 42)
		t:SetPoint("TOPRIGHT")
		t:SetTexture("Interface/Garrison/AdventureMissionsFrame")
		t:SetTexCoord(650/1024, 688/1024, 1119/2048, 1158/2048)
		Mirror(t, true, false)
		t = border:CreateTexture(nil, "BACKGROUND", nil, 1)
		t:SetSize(42, 42)
		t:SetPoint("BOTTOMLEFT")
		t:SetTexture("Interface/Garrison/AdventureMissionsFrame")
		t:SetTexCoord(650/1024, 688/1024, 1119/2048, 1158/2048)
		Mirror(t, false, true)
		t = border:CreateTexture(nil, "BACKGROUND", nil, 1)
		t:SetSize(42, 42)
		t:SetPoint("BOTTOMRIGHT")
		t:SetTexture("Interface/Garrison/AdventureMissionsFrame")
		t:SetTexCoord(650/1024, 688/1024, 1119/2048, 1158/2048)
		Mirror(t, true, true)
		t = parent:CreateTexture(nil, "BACKGROUND", nil, -2)
		t:SetTexture("Interface/FrameGeneral/UIFrame"..CovenKit.."Background", true, true)
		t:SetHorizTile(true)
		t:SetVertTile(true)
		t:SetAllPoints(border)
		t:SetVertexColor(0.95, 0.95, 0.95)
		t = parent:CreateTexture(nil, "BACKGROUND", nil, -1)
		t:SetAtlas("Adventures-Missions-Shadow")
		t:SetAllPoints(border)
		t:SetAlpha(0.45)
	end
end
function Factory.LockedCopyInputBox(parent)
	local f = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	f:SetHighlightColor(1,0.8,0.3, 0.6)
	f:SetScript("OnEscapePressed", f.ClearFocus)
	f:SetScript("OnTextChanged", LockedInputBox_OnTextChanged)
	f:SetAutoFocus(false)
	f:SetSize(250, 20)
	return f
end
function Factory.CopyBoxUI(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(335, 340)
	f:SetFrameLevel(600)
	f:SetPoint("CENTER")
	local fbg = CreateFrame("Button", nil, f)
	fbg:SetAllPoints(parent)
	fbg:SetScript("OnMouseWheel", function() end)
	fbg:SetScript("OnClick", function() if not f:IsMouseOver(0, 0, -10, 10) then f:Hide() end end)
	fbg:RegisterForClicks("AnyUp")
	fbg:EnableMouse(true)
	fbg:SetFrameLevel(500)
	local t = fbg:CreateTexture(nil, "BACKGROUND")
	t:SetColorTexture(0,0,0,0.9)
	t:SetAllPoints()
	t = f:CreateTexture(nil, "BACKGROUND")
	t:SetAtlas("UI-Frame-"..CovenKit.."-CardParchmentWider")
	t:SetAllPoints()
	t = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge2")
	t:SetText("Moonkittens for sale")
	t:SetPoint("TOP", 0, -34)
	t, f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontBlackMedium"), t
	t:SetWidth(270)
	t:SetPoint("TOP", f.Title, "BOTTOM", 0, -10)
	t:SetJustifyH("LEFT")
	t:SetTextColor(0.1, 0.1, 0.1)
	t:SetText("These adorable rascals are guaranteed to moonfire literally everything around them.");
	t, f.Intro = f:CreateFontString(nil, "OVERLAY", "GameFontBlackMedium"), t
	t:SetWidth(270)
	t:SetJustifyH("LEFT")
	t:SetText("1. Moonfire.")
	t:SetTextColor(0.1, 0.1, 0.1)
	local ub = CreateObject("LockedCopyInputBox", f)
	ub:SetPoint("TOP", f.Intro, "BOTTOM", 0, -60)
	ub:SetText("Very moon,")
	ub:SetTextColor(0.25, 0.75, 1)
	t:SetPoint("BOTTOM", ub, "TOP", 0, 6)
	f.FirstInputBox = ub
	f.FirstInputBoxLabel = t

	local cb = CreateObject("LockedCopyInputBox", f)
	cb:SetPoint("TOP", ub, "TOP", 0, -50)
	cb:SetText("Much fire!")
	f.SecondInputBox = cb
	t = f:CreateFontString(nil, "OVERLAY", "GameFontBlackMedium")
	t:SetWidth(270)
	t:SetJustifyH("LEFT")
	t:SetPoint("BOTTOM", cb, "TOP", 0, 6)
	t:SetText("2. Kittens.")
	t:SetTextColor(0.1, 0.1, 0.1)
	f.SecondInputBoxLabel = t

	f:SetScript("OnKeyDown", function(self, key)
		f:SetPropagateKeyboardInput(key ~= "ESCAPE")
		if key == "ESCAPE" then
			self:Hide()
		end
	end)

	t = CreateObject("PanelButton", f)
	t:SetPoint("BOTTOM", 0, 34 + (UIBUTTON_HEIGHT-22)/2)
	t:SetWidth(216)
	t:SetText("Reset")
	t, f.ResetButton = CreateFrame("Button", nil, f, "UIPanelCloseButtonNoScripts"), t
	t:SetPoint("TOPRIGHT", -8, -8)
	t:SetScript("OnClick", function()
		f:Hide()
	end)
	t, f.CloseButton2 = f:CreateFontString(nil, "OVERLAY", "GameFontBlackSmall"), t
	t:SetPoint("BOTTOMRIGHT", -16, 14)
	t:SetText(GetAddOnMetadata(AN, "Title") .. " v" .. GetAddOnMetadata(AN, "Version"))
	f.VersionText = t

	f:SetScript("OnHide", function(self)
		if self:IsShown() then
			self:Hide()
		else
			PlaySound(170568)
		end
		if self:GetParent().keyFocus == self then
			self:GetParent().keyFocus = nil
		end
	end)
	f:SetScript("OnShow", function(self)
		self:GetParent().keyFocus = self
	end)

	return f
end
function Factory.MissionPage(parent)
	local f = CreateFrame("Frame", nil, parent)
	local s = CreateObject("Shadow", f)
	f:SetAllPoints()
	f:EnableMouse(true)
	s.MissionList = CreateObject("MissionList", f)
	s.CopyBox = CreateObject("CopyBoxUI", f)
	s.CopyBox:Hide()
	local resButton = CreateObject("ResourceButton", f, 1813) do
		s.ResourceCounter = resButton
		resButton:SetPoint("TOPRIGHT", -72, -30)
	end
	local ccButton = CreateObject("ILButton", f) do
		s.CompanionCounter = ccButton
		ccButton.Icon:SetTexture("Interface/FriendsFrame/Battlenet-Battleneticon")
		ccButton.Icon:SetTexCoord(6/32,26/32, 6/32,26/32)
		ccButton.Icon:SetBlendMode("ADD")
		ccButton:SetPoint("RIGHT", resButton, "LEFT", -30, 0)
		ccButton:SetScript("OnEnter", AwayFollowers_OnEnter)
	end
	local prButton = CreateObject("ResourceButton", f, 1889) do
		s.ProgressCounter = prButton
		prButton:SetPoint("RIGHT", ccButton, "LEFT", -35, 0)
	end
	local logsButton = CreateObject("ILButton", f, 1889) do
		s.LogCounter = logsButton
		logsButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		logsButton.Icon:SetTexture("Interface/Icons/INV_Inscription_80_Scroll")
		logsButton:SetPoint("RIGHT", prButton, "LEFT", -35, 0)
	end
	local uButton = CreateObject("PanelButton", f) do
		s.UnButton, uButton.Glow = uButton, CreateObject("PanelButtonGlow", uButton)
		uButton:SetWidth(200)
		uButton:SetPoint("TOPLEFT", 200, -34)
		uButton:Hide()
		uButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		uButton:SetScript("OnEnter", UButton_OnEnter)
		uButton:SetScript("OnClick", UButton_OnClick)
		uButton:SetScript("OnLeave", HideOwnGameTooltip)
		uButton:SetScript("OnKeyDown", UButton_OnKeyDown)
		uButton.Sync = UButton_Sync
	end
	local sButton = CreateObject("PanelButton", f) do
		s.StartButton = sButton
		sButton:Hide()
		sButton:SetWidth(26)
		sButton:SetPoint("LEFT", uButton, "RIGHT", 4, 0)
		sButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		sButton:SetScript("OnEnter", UButton_OnEnter)
		sButton:SetScript("OnClick", UButton_OnClick)
		sButton:SetScript("OnLeave", HideOwnGameTooltip)
		sButton:SetText("|TInterface/RaidFrame/UI-RaidFrame-Arrow:22:30:-3:-1|t")
	end
	local vButton = CreateObject("CommonHoverTooltip", CreateFrame("Button", nil, f)) do
		s.Version = vButton
		vButton:Disable()
		vButton:SetMotionScriptsWhileDisabled(true)
		local an = GetAddOnMetadata(AN, "Title") or AN or ""
		local av = GetAddOnMetadata(AN, "Version") or "Q"
		local aw = GetAddOnMetadata(AN, "X-Website")
		vButton:SetPoint("BOTTOMRIGHT", -62, 20)
		vButton:SetSize(110, 20)
		vButton:SetPushedTextOffset(0,0)
		vButton:SetNormalFontObject(GameFontNormalSmall)
		vButton:SetDisabledFontObject(GameFontNormalSmall)
		vButton:SetText("|cff787878" .. an .. " |r|cffb0b0b0" .. av)
		local fs = vButton:GetFontString()
		fs:ClearAllPoints()
		fs:SetPoint("RIGHT")
		vButton.tooltipHeader, vButton.tooltipTextNW, vButton.tooltipAnchor = an, true, "ANCHOR_TOPRIGHT"
		vButton.tooltipText = aw and "|cff20a0ff" .. aw or nil
	end
	s.Toasts = {CreateObject("MissionToast", f)}
	s.Toasts[1]:SetPoint("TOPLEFT", 20, -62)
	s.AcquireToast = MissionPage_AcquireToast
	return s
end
function Factory.MissionList(parent)
	local coven = C_Covenants.GetCovenantData(C_Covenants.GetActiveCovenantID() or 1)
	CovenKit = coven and coven.textureKit or "NightFae"

	local missionList = CreateFrame("ScrollFrame", nil, parent)
	local s = CreateObject("Shadow", missionList)
	missionList:SetSize(892, 524)
	missionList:SetPoint("TOP", 0, -72)
	missionList:EnableMouseWheel(true)
	missionList.ScrollToward = MissionList_ScrollToward
	CreateObject("RaisedBorder", missionList)
	do -- missionList:OnMouseWheel
		local v = CreateFrame("Frame", nil, parent)
		v:SetAllPoints(missionList)
		v:EnableMouse(true)
		v:SetFrameLevel(parent:GetFrameLevel()+20)
		v:Hide()
		s.ScrollVeil = v
		local function scrollFinish(self)
			local se = S[self]
			self:GetScrollChild():SetPoint("TOPLEFT", 0, se.scrollEnd)
			se.scrollStart, se.scrollEnd, se.scrollTimeStart, se.scrollTimeEnd, se.scrollSpeed, se.scrollLast = nil
			self:SetScript("OnUpdate", nil)
			self:SetScript("OnHide", nil)
			se.ScrollVeil:Hide()
		end
		local function scrollOnUpdate(self)
			local se = S[self]
			local a, b, s, t = se.scrollStart, se.scrollEnd, se.scrollTimeStart, se.scrollTimeEnd
			local sc, c = self:GetScrollChild(), GetTime()
			if c >= t then
				scrollFinish(self)
			else
				local p = a + (b-a)*(c-s)/(t-s)
				sc:SetPoint("TOPLEFT", 0, p)
				se.scrollLastTime, se.scrollLastOffset = c, s
			end
		end
		local function onMouseWheel(self, d)
			local se, y = S[self], select(5, self:GetScrollChild():GetPoint())
			local snap = math.min(math.max(0, (se.scrollSnap or 0) - d), math.floor(((se.numMissions or 0)-1)/3)-1)
			local dy = snap == 0 and 0 or (195*snap-30)
			if se.scrollEnd ~= dy then
				local ct = GetTime()
				se.scrollSnap, se.scrollStart, se.scrollEnd, se.scrollTimeStart, se.scrollTimeEnd = snap, y, dy, ct, ct + 0.20
				self:SetScript("OnUpdate", scrollOnUpdate)
				self:SetScript("OnHide", scrollFinish)
				S[self].ScrollVeil:Show()
			end
		end
		missionList:SetScript("OnMouseWheel", onMouseWheel)
		missionList:SetScript("OnKeyDown", function(self, k)
			self:SetPropagateKeyboardInput(true)
			if k == "PAGEDOWN" or k == "PAGEUP" then
				self:SetPropagateKeyboardInput(false)
				onMouseWheel(self, k == "PAGEDOWN" and -2 or 2)
			elseif k == "HOME" or k == "END" then
				self:SetPropagateKeyboardInput(false)
				onMouseWheel(self, k == "END" and -math.huge or math.huge)
			end
		end)
		function missionList:ReturnToTop()
			local se = S[self]
			se.scrollSnap, se.scrollEnd = 0, 0
			scrollFinish(self)
		end
		function missionList:CheckScrollRange()
			onMouseWheel(self, 0)
		end
	end
	local scrollChild = CreateFrame("Frame", nil, missionList)
	scrollChild:SetPoint("TOPLEFT")
	scrollChild:SetSize(902,missionList:GetHeight())
	missionList:SetScrollChild(scrollChild)
	s.Missions = setmetatable({}, {__index=MissionList_SpawnMissionButton, __metatable=false})
	for i=1,6 do
		local cf = CreateObject("MissionButton", scrollChild)
		s.Missions[i] = cf
		cf:SetPoint("TOPLEFT", 292*(((i-1)%3)+1)-284, math.floor((i-1)/3) *- 195)
	end

	return s
end
function Factory.MissionButton(parent)
	local cf, t = CreateFrame("Button", nil, parent)
	local s = CreateObject("Shadow", cf)
	cf:SetSize(290, 196)
	cf:SetScript("OnClick", MissionButton_OnClick)
	t = cf:CreateTexture(nil, "BACKGROUND", nil, -2)
	t:SetAtlas("UI-Frame-"..CovenKit.."-CardParchmentWider")
	t:SetPoint("TOPLEFT", 0, -24)
	t:SetPoint("BOTTOMRIGHT", 0, 0)
	Mirror(t, true)
	t = cf:CreateTexture(nil, "ARTWORK", nil, -6)
	t:SetAtlas("UI-Frame-"..CovenKit.."-CardParchmentWider")
	t:SetPoint("TOPLEFT", 0, -24)
	t:SetPoint("BOTTOMRIGHT", 0, 0)
	t:SetVertexColor(0.30, 0.30, 0.40, 0.60)
	Mirror(t, true)
	t, s.Veil = cf:CreateFontString(nil, "BACKGROUND", "GameFontHighlightLarge"), t
	t:SetText("Beast Beneath the Hydrant")
	t:SetPoint("TOP", 0, -55.5)
	t:SetWidth(276)
	t:SetTextColor(0.97, 0.94, 0.70)
	t, s.Name = cf:CreateTexture(nil, "BACKGROUND", nil, 2), t
	t:SetAtlas("Campaign-QuestLog-LoreDivider")
	local divC = CovenKit == "Kyrian" and 0xfeb0a0 or CovenKit == "Venthyr" and 0xfe40f0 or CovenKit == "Necrolord" and 0xc0fe00 or 0x4080fe
	t:SetVertexColor(divC / 2^24, divC/256 % 256 / 255, divC%256/255)
	t:SetWidth(286)
	t:SetPoint("TOP", s.Name, 0, 6)
	t:SetPoint("BOTTOM", s.Name, "BOTTOM", 0, -5)
	t = cf:CreateFontString(nil, "OVERLAY", "GameFontBlack")
	t:SetWidth(262)
	t:SetPoint("TOP", s.Name, "BOTTOM", 0, -28.5)
	t:SetText("Nyar!")
	t, s.Description = CreateObject("CommonHoverTooltip", CreateFrame("Button", nil, cf)), t
	t:SetNormalFontObject(GameFontBlack)
	t:SetSize(40, 16)
	t:SetPoint("BOTTOMLEFT", cf, 14, 13)
	t:SetText("Expired")
	t:GetFontString():SetJustifyH("LEFT")
	t:SetMouseClickEnabled(false)
	s.ExpireTime = t
	CreateObject("CountdownText", cf, s.ExpireTime)
	s.Rewards = CreateObject("RewardBlock", cf, 48, 4)
	s.Rewards.Container:SetPoint("TOP", 0, -4)
	t = CreateObject("AchievementRewardIcon", cf)
	t:SetPoint("RIGHT", cf, "TOPRIGHT", -25, -40)
	s.AchievementReward = t

	t = CreateFrame("Frame", nil, cf)
	t:SetPoint("TOP", s.Name, "BOTTOM", 0, -6)
	t:SetSize(224, 20)
	local a, b = cf:CreateTexture(nil, "BACKGROUND", nil, 2)
	a:SetAtlas("ui_adv_health", true)
	a:SetPoint("LEFT", t, "LEFT", -6, 0)
	b = t:CreateFontString(nil, "OVERLAY", "GameFontBlack")
	b:SetPoint("LEFT", a, "RIGHT", -2, 0)
	b:SetText("2,424")
	a, s.enemyHP = cf:CreateTexture(nil, "BACKGROUND", nil, 2), b
	a:SetAtlas("ui_adv_atk", true)
	a:SetPoint("LEFT", b, "RIGHT", 0, 0)
	b = t:CreateFontString(nil, "OVERLAY", "GameFontBlack")
	b:SetPoint("LEFT", a, "RIGHT", -2, 0)
	b:SetText("2,424")
	a, s.enemyATK = cf:CreateTexture(nil, "BACKGROUND", nil, 2), b
	a:SetAtlas("animachannel-bar-" .. CovenKit .. "-gem", true)
	a:SetPoint("LEFT", b, "RIGHT", 8, 0)
	b = t:CreateFontString(nil, "OVERLAY", "GameFontBlack")
	b:SetPoint("LEFT", a, "RIGHT", -2, 0)
	b:SetText("42")
	a, s.animaCost = cf:CreateTexture(nil, "BACKGROUND", nil, 2), b
	a:SetTexture("Interface/Common/Mini-hourglass")
	a:SetSize(14, 14)
	a:SetVertexColor(0.5, 0.75, 1)
	a:SetPoint("LEFT", b, "RIGHT", 8, 0)
	b = t:CreateFontString(nil, "OVERLAY", "GameFontBlack")
	b:SetPoint("LEFT", a, "RIGHT", 2, 0)
	s.duration = b
	s.statLine = t

	t = CreateObject("ProgressBar", cf)
	t:SetWidth(cf:GetWidth()-50)
	t:SetPoint("BOTTOM", 0, 14)
	t:SetHitRectInsets(-6, -6, -6, -6)
	t.Fill:SetAtlas("UI-Frame-Bar-Fill-Blue")
	t:SetScript("OnClick", MissionButton_OnProgressBarClick)
	s.ProgressBar = t
	local gb = CreateObject("PanelButton", cf)
	gb:SetPoint("BOTTOM", 20, 10)
	gb:SetText("Buttons!")
	gb:SetWidth(165)
	gb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	gb:SetScript("OnClick", MissionButton_OnViewClick)
	s.ViewButton = gb
	t = CreateObject("PanelButton", cf)
	t:SetPoint("RIGHT", s.ViewButton, "LEFT", -8)
	t:SetWidth(24)
	t:SetText("|TInterface/EncounterJournal/UI-EJ-HeroicTextIcon:0|t")
	t:SetPushedTextOffset(-1, -1)
	t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	t:SetScript("OnEnter", DoomRun_OnEnter)
	t:SetScript("OnLeave", HideOwnGameTooltip)
	t:SetScript("OnClick", DoomRun_OnClick)
	t:SetScript("OnShow", DoomRun_OnShow)
	t, s.DoomRunButton = CreateObject("PanelButton", cf), t
	t:SetAllPoints(s.DoomRunButton)
	t:SetText("|TInterface/Buttons/UI-StopButton:0|t")
	t:SetScript("OnClick", TentativeGroupClear_OnClick)
	t:SetPushedTextOffset(-1, -1)
	s.TentativeClear = t
	t = cf:CreateFontString(nil, "BACKGROUND", "GameFontNormalSmall")
	t:SetTextColor(0.97, 0.94, 0.70)
	t:SetPoint("TOPLEFT", 16, -38)
	t, s.TagText = CreateObject("BoardGroup", cf), t
	t:SetWidth(272)
	t:SetPoint("TOP", s.Name, "BOTTOM", 0, -24)
	t:SetPoint("BOTTOM", 0, 37)
	s.Group = t
	s.SetGroupPortraits = MissionButton_SetGroupPortraits

	return cf
end
function Factory.BoardGroup(parent)
	local f, t, r = CreateFrame("Frame", nil, parent)
	local s = CreateObject("Shadow", f)
	for i=0,4 do
		t = f:CreateTexture(nil, "ARTWORK", nil, 1)
		r = f:CreateTexture(nil, "ARTWORK", nil, 2)
		t:SetSize(36, 36)
		r:SetAtlas("GarrMission_PortraitRing_Enemy")
		r:SetPoint("TOPRIGHT", t, "TOPRIGHT", 3.5, 3.5)
		r:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", -3.5, -3.5)
		s[i], s[5+i] = t, r
	end
	s[0]:SetPoint("BOTTOM", -44, 5)
	s[1]:SetPoint("BOTTOM", 44, 5)
	s[2]:SetPoint("TOP", -88, -5)
	s[3]:SetPoint("TOP", 0, -5)
	s[4]:SetPoint("TOP", 88, -5)
	return f
end
function Factory.RewardFrame(parent, sz)
	sz = sz or 48
	local f, t = CreateObject("CommonHoverTooltip", CreateFrame("Button", nil, parent))
	f:SetSize(sz, sz)
	t = f:CreateTexture(nil, "ARTWORK")
	local o = sz*6/64
	t:SetPoint("TOPLEFT", o, -o)
	t:SetPoint("BOTTOMRIGHT", -o, o)
	t:SetTexture("Interface/Icons/Temp")
	t:SetTexCoord(4/64, 60/64, 4/64, 60/64)
	t, f.Icon = f:CreateTexture(nil, "ARTWORK", nil, 2), t
	t:SetAllPoints()
	t:SetAtlas("loottoast-itemborder-orange")
	t, f.RarityBorder = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightOutline"), t
	t:SetPoint("BOTTOMRIGHT", -4, 5)
	f.Quantity = t
	f:SetScript("OnClick", CommonLinkable_OnClick)
	f.SetReward = RewardButton_SetReward
	return f
end
function Factory.RewardBlock(parent, sz, sp)
	local t, s, r = CreateFrame("Frame", nil, parent), sz+(sp or 3)
	t:SetSize(s+sz, sz)
	r = {Container=t, SetRewards=RewardBlock_SetRewards}
	for j=1,3 do
		local rew = CreateObject("RewardFrame", t, sz)
		rew:SetPoint("LEFT", s*j-s, 0)
		r[j] = rew
	end
	return r
end
function Factory.InlineRewardBlock(parent)
	local f, t = CreateFrame("Frame", nil, parent)
	f:EnableMouse(true)
	f:SetSize(140, 28)
	t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	t:SetPoint("LEFT")
	t:SetText(L"Rewards:")
	f.Rewards = {Label=t}
	for i=1,3 do
		t = CreateObject("RewardFrame", f, 28)
		t:SetPoint("LEFT", f.Rewards[i-1] or f.Rewards.Label, "RIGHT", i == 1 and 12 or 4, 0)
		t.Quantity:Hide()
		t.ShowQuantityFromWidgetText = "Quantity"
		f.Rewards[i] = t
	end
	f.Rewards.SetRewards = RewardBlock_SetRewards
	return f
end
function Factory.CommonHoverTooltip(frame)
	frame:SetScript("OnEnter", CommonTooltip_OnEnter)
	frame:SetScript("OnLeave", HideOwnGameTooltip)
	return frame
end
function Factory.MissionBaseBackground(parent, expandW, expandH)
	local eX, eY, t = expandW or 10, expandH or expandW or 10
	t = parent:CreateTexture(nil, "BORDER")
	t:SetAtlas("Garr_InfoBoxMission-BackgroundTile")
	t:SetPoint("TOPLEFT", -eX, eY)
	t:SetPoint("BOTTOMRIGHT", eX, -eY)
	t = parent:CreateTexture(nil, "BORDER", nil, 1)
	parent["BaseFrameTop"] = t
	t:SetAtlas("_Garr_InfoBoxMission-Top", true)
	t:SetHorizTile(true)
	t:SetPoint("TOPLEFT", 1-eX, 7+eY)
	t:SetPoint("TOPRIGHT", -1+eX, 7+eY)
	t = parent:CreateTexture(nil, "BORDER", nil, 1)
	parent["BaseFrameBottom"] = t
	t:SetAtlas("_Garr_InfoBoxMission-Top", true)
	t:SetHorizTile(true)
	t:SetPoint("BOTTOMLEFT", -eX, -7-eY)
	t:SetPoint("BOTTOMRIGHT", eX, -7-eY)
	t:SetTexCoord(0.0, 1.0, 1.0, 0.0)
	t = parent:CreateTexture(nil, "BORDER", nil, 1)
	parent["BaseFrameLeft"] = t
	t:SetAtlas("!Garr_InfoBoxMission-Left", true)
	t:SetVertTile(true)
	t:SetPoint("TOPLEFT", -7-eX, eY)
	t:SetPoint("BOTTOMLEFT", -7-eX, -eY)
	t = parent:CreateTexture(nil, "BORDER", nil, 1)
	parent["BaseFrameRight"] = t
	t:SetAtlas("!Garr_InfoBoxMission-Left", true)
	t:SetVertTile(true)
	t:SetPoint("TOPRIGHT", 7+eX, eY)
	t:SetPoint("BOTTOMRIGHT", 7+eX, -eY)
	t:SetTexCoord(1.0, 0.0, 0.0, 1.0)

	t = parent:CreateTexture(nil, "BORDER", nil, 2)
	parent["BaseFrameTopLeft"] = t
	t:SetAtlas("Garr_InfoBoxMission-Corner", true)
	t:SetPoint("TOPLEFT", -6-eX, 7+eY)
	t = parent:CreateTexture(nil, "BORDER", nil, 2)
	parent["BaseFrameTopRight"] = t
	t:SetAtlas("Garr_InfoBoxMission-Corner", true)
	t:SetPoint("TOPRIGHT", 6+eX, 7+eY)
	t:SetTexCoord(1.0, 0.0, 0.0, 1.0)
	t = parent:CreateTexture(nil, "BORDER", nil, 2)
	parent["BaseFrameBottomLeft"] = t
	t:SetAtlas("Garr_InfoBoxMission-Corner", true)
	t:SetPoint("BOTTOMLEFT", -7-eX, -7-eY)
	t:SetTexCoord(0.0, 1.0, 1.0, 0.0)
	t = parent:CreateTexture(nil, "BORDER", nil, 2)
	parent["BaseFrameBottomRight"] = t
	t:SetAtlas("Garr_InfoBoxMission-Corner", true)
	t:SetPoint("BOTTOMRIGHT", 7+eX, -7-eY)
	t:SetTexCoord(1.0, 0.0, 1.0, 0.0)

	t = parent:CreateTexture(nil, "BORDER", nil, 4)
	t:SetAtlas("_Garr_InfoBoxBorderMission-Top", true)
	t:SetHorizTile(true)
	t:SetPoint("TOPLEFT", -eX,eY)
	t:SetPoint("TOPRIGHT", eX,eY)
	t = parent:CreateTexture(nil, "BORDER", nil, 4)
	t:SetAtlas("_Garr_InfoBoxBorderMission-Top", true)
	t:SetHorizTile(true)
	t:SetPoint("BOTTOMLEFT", -eX,-eY)
	t:SetPoint("BOTTOMRIGHT", eX,-eY)
	t:SetTexCoord(0.0, 1.0, 1.0, 0.0)
	t = parent:CreateTexture(nil, "BORDER", nil, 4)
	t:SetAtlas("!Garr_InfoBoxBorderMission-Left", true)
	t:SetVertTile(true)
	t:SetPoint("TOPLEFT", -eX,eY)
	t:SetPoint("BOTTOMLEFT", -eX,-eY)
	t = parent:CreateTexture(nil, "BORDER", nil, 4)
	t:SetAtlas("!Garr_InfoBoxBorderMission-Left", true)
	t:SetVertTile(true)
	t:SetPoint("TOPRIGHT", eX,eY)
	t:SetPoint("BOTTOMRIGHT", eX,-eY)
	t:SetTexCoord(1.0, 0.0, 0.0, 1.0)

	t = parent:CreateTexture(nil, "BORDER", nil, 5)
	t:SetAtlas("Garr_InfoBoxBorderMission-Corner", true)
	t:SetPoint("TOPLEFT", -eX, eY)
	t = parent:CreateTexture(nil, "BORDER", nil, 5)
	t:SetAtlas("Garr_InfoBoxBorderMission-Corner", true)
	t:SetPoint("TOPRIGHT", eX, eY)
	t:SetTexCoord(1.0, 0.0, 0.0, 1.0)
	t = parent:CreateTexture(nil, "BORDER", nil, 5)
	t:SetAtlas("Garr_InfoBoxBorderMission-Corner", true)
	t:SetPoint("BOTTOMLEFT", -eX, -eY)
	t:SetTexCoord(0.0, 1.0, 1.0, 0.0)
	t = parent:CreateTexture(nil, "BORDER", nil, 5)
	t:SetAtlas("Garr_InfoBoxBorderMission-Corner", true)
	t:SetPoint("BOTTOMRIGHT", eX, -eY)
	t:SetTexCoord(1.0, 0.0, 1.0, 0.0)
end
function Factory.CountdownText(widget, textWidget)
	widget.SetCountdown = CountdownText_SetCountdown
	widget.CDTDisplay = textWidget or widget
end
function Factory.AchievementRewardIcon(parent)
	local f, t = CreateObject("CommonHoverTooltip", CreateFrame("Button", nil, parent))
	f:SetSize(30,30)
	f:SetScript("OnHide", HideOwnGameTooltip)
	f:SetScript("OnClick", CommonLinkable_OnClick)
	t = f:CreateTexture(nil, "ARTWORK")
	t:SetTexture("Interface/AchievementFrame/UI-Achievement-Progressive-Shield")
	t:SetTexCoord(0, 0.75, 0, 0.75)
	t:SetAllPoints()
	return f
end
function Factory.ProgressBar(parent)
	local f, t, r = CreateFrame("Button", nil, parent)
	f:Disable()
	f:SetHeight(16)
	f:SetHitRectInsets(-3, -3, -6, -4)
	t = f:CreateTexture(nil, "BACKGROUND")
	t:SetAtlas("UI-Frame-Bar-BGLeft", true)
	t:SetPoint("LEFT", -2,0)
	t = f:CreateTexture(nil, "BACKGROUND")
	t:SetAtlas("UI-Frame-Bar-BGRight", true)
	t:SetPoint("RIGHT", 2,0)
	t = f:CreateTexture(nil, "BACKGROUND")
	t:SetAtlas("UI-Frame-Bar-BGCenter")
	t:SetPoint("LEFT", 27,0)
	t:SetPoint("RIGHT", -27,0)
	t:SetHeight(18)
	t = f:CreateTexture(nil, "BORDER")
	t:SetAtlas("UI-Frame-Bar-BorderLeft", true)
	t:SetPoint("LEFT", -8,0)
	t = f:CreateTexture(nil, "BORDER")
	t:SetAtlas("UI-Frame-Bar-BorderRight", true)
	t:SetPoint("RIGHT", 8,0)
	t = f:CreateTexture(nil, "BORDER")
	t:SetAtlas("UI-Frame-Bar-BorderCenter")
	t:SetPoint("LEFT", 27,0)
	t:SetPoint("RIGHT", -27,0)
	t:SetHeight(31)
	t, r = f:CreateTexture(nil, "HIGHLIGHT"), CreateObject("ObjectGroup")
	t:SetAtlas("UI-Frame-Bar-BorderLeft", true)
	t:SetPoint("LEFT", -8,0)
	t, r[#r+1] = f:CreateTexture(nil, "HIGHLIGHT"), t
	t:SetAtlas("UI-Frame-Bar-BorderRight", true)
	t:SetPoint("RIGHT", 8,0)
	t, r[#r+1] = f:CreateTexture(nil, "HIGHLIGHT", nil, 2), t
	t:SetAtlas("UI-Frame-Bar-BorderCenter")
	t:SetPoint("LEFT", 27,0)
	t:SetPoint("RIGHT", -27,0)
	t:SetHeight(31)
	r[#r+1], f.Highlight = t, r
	r:SetBlendMode("ADD")
	t = f:CreateTexture(nil, "BACKGROUND", nil, 2)
	t:SetAtlas("UI-Frame-Bar-Fill-Red")
	t:SetPoint("TOPLEFT")
	t:SetPoint("BOTTOMLEFT")
	t:SetWidth(50)
	f:SetText(" ")
	t, f.Fill = f:GetFontString(), t
	t:SetFontObject(GameFontHighlight)
	f:SetPushedTextOffset(-1, -1)
	t:SetPoint("TOPLEFT", 4, 0)
	t:SetPoint("BOTTOMRIGHT", -4, 1)
	t:SetJustifyV("MIDDLE")
	f.Text = t
	f.SetProgress = Progress_SetProgress
	f.SetProgressCountdown = Progress_SetTimer
	return f
end
function Factory.TooltipProgressBar()
	local f, t = CreateFrame("Frame")
	f:SetSize(180, 30)
	f:Hide()
	t = CreateObject("ProgressBar", f)
	t:SetPoint("LEFT", 8, 0)
	t:SetPoint("RIGHT", -8, 0)
	t:SetClipsChildren(true)
	t.Fill:SetAtlas("UI-Frame-Bar-Fill-Blue")
	t, f.Bar = t:CreateTexture(nil, "BACKGROUND", nil, 2), t
	t:SetAtlas("UI-Frame-Bar-Fill-Yellow")
	t:SetPoint("TOPLEFT", f.Bar.Fill, "TOPRIGHT")
	t:SetPoint("BOTTOMLEFT", f.Bar.Fill, "BOTTOMRIGHT")
	t:SetWidth(50)
	f.Activate, f.Fill2 = TooltipProgressBar_Activate, t
	f:SetScript("OnHide", TooltipProgressBar_OnHide)
	f:SetScript("OnUpdate", TooltipProgressBar_Update)
	return f
end
function Factory.ControlContainerBorder(parent, expandX, expandY)
	expandX, expandY = expandX or 0, expandY or 0
	local t, is, ts = parent:CreateTexture(nil, "BACKGROUND"), 18, 1/16
	t:SetAtlas("adventures_mission_materialframe")
	t:SetTexCoord(0, ts, 0, 1)
	t:SetPoint("TOPLEFT", -expandX, expandY)
	t:SetPoint("BOTTOMRIGHT", parent, "BOTTOMLEFT", is-expandX, -expandY)
	t = parent:CreateTexture(nil, "BACKGROUND")
	t:SetTexCoord(ts, 1-ts, 0, 1)
	t:SetAtlas("adventures_mission_materialframe")
	t:SetPoint("TOPLEFT", is-expandX, expandY)
	t:SetPoint("BOTTOMRIGHT", -is+expandX, -expandY)
	t = parent:CreateTexture(nil, "BACKGROUND")
	t:SetTexCoord(1-ts, 1, 0, 1)
	t:SetAtlas("adventures_mission_materialframe")
	t:SetPoint("TOPRIGHT", expandX, expandY)
	t:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", -is+expandX, -expandY)
end
function Factory.ILButton(parent)
	local f = CreateObject("CommonHoverTooltip", CreateFrame("Button", nil, parent))
	f:SetSize(60, 23)
	f.tooltipAnchor, f.tooltipYO = "ANCHOR_BOTTOM", -6
	local t = f:CreateTexture()
	t:SetSize(18, 18)
	t:SetTexture("Interface/Icons/Temp")
	t:SetTexCoord(4/64,60/64, 4/64,60/64)
	t:SetPoint("LEFT", 1, 0)
	t, f.Icon = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightMed2"), t
	t:SetPoint("LEFT", 25, 0)
	f.SetText, f.Text = ResizedButton_SetText, t
	f:SetText("00")
	CreateObject("ControlContainerBorder", f, 15, 9)
	return f
end
function Factory.ResourceButton(parent, currencyID)
	local f = CreateObject("ILButton", parent)
	f.currencyID = currencyID
	f:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
	f:SetScript("OnEvent", ResourceButton_Update)
	f:SetScript("OnClick", ResourceButton_OnClick)
	local ci = C_CurrencyInfo.GetCurrencyInfo(currencyID)
	f.Icon:SetTexture(ci and ci.iconFileID or "Interface/Icons/Temp")
	ResourceButton_Update(f, nil, currencyID)
	return f
end
function Factory.FollowerListButton(parent, isTroop)
	local f,t = CreateFrame("Button", nil, parent)
	local s = CreateObject("Shadow", f)
	local f2 = CreateFrame("Frame", nil, f)
	local ett = {}
	f2:SetAllPoints()
	f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	f:RegisterForDrag("LeftButton")
	f:SetMotionScriptsWhileDisabled(true)
	f:SetHitRectInsets(-3,4,0,5)
	f:SetScript("OnDragStart", FollowerButton_OnDragStart)
	f:SetScript("OnDragStop", FollowerButton_OnDragStop)
	f:SetScript("OnClick", FollowerButton_OnClick)
	f:SetScript("OnEnter", FollowerButton_OnEnter)
	f:SetScript("OnLeave", HideOwnGameTooltip)
	f:SetSize(70, 70)
	t = f:CreateTexture(nil, "BORDER")
	t:SetAtlas(isTroop and "adventurers-followers-frame-troops" or "adventurers-followers-frame")
	t:SetSize(60, 60)
	t:SetPoint("CENTER", 0, 5)
	t, s.PortraitR = f:CreateTexture(nil, "BORDER", nil, 2), t
	t:SetAtlas("adventurers-followers-xp")
	t:SetVertexColor(1, 0.35, 0)
	t:SetSize(50, 51)
	t:SetPoint("CENTER", 0, 5)
	t, s.PortraitT = f:CreateTexture(nil, "BACKGROUND", nil, 1), t
	t:SetSize(46, 46)
	t:SetPoint("CENTER", 0, 5)
	t:SetTexture(1605024)
	t:SetDesaturated(true)
	t:SetBlendMode("ADD")
	t:SetAlpha(0.5)
	t, s.Portrait2 = f:CreateTexture(nil, "BACKGROUND"), t
	t:SetSize(46, 46)
	t:SetPoint("CENTER", 0, 5)
	t:SetTexture(1605024)
	t, s.Portrait = f2:CreateTexture(nil, "ARTWORK", nil, -1), t
	t:SetColorTexture(1,1,1)
	t:SetGradient("VERTICAL", 0.15,0.15,0.15, 0.2,0.2, 0.2)
	t:SetSize(39, 12)
	t:SetPoint("BOTTOMRIGHT", -9, 10)
	t, s.HealthBG = f2:CreateTexture(nil, "ARTWORK"), t
	t:SetColorTexture(1,1,1)
	t:SetGradient("VERTICAL", 0.10,0.25,0.10, 0.05,0.5,0.05)
	t:SetAlpha(0.85)
	t:SetSize(24, s.HealthBG:GetHeight())
	t:SetPoint("BOTTOMLEFT", s.HealthBG, "BOTTOMLEFT")
	t, s.Health = f2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"), t
	t:SetPoint("BOTTOMLEFT", f, "BOTTOM", -6, 11)
	t, s.TextLabel = f2:CreateTexture(nil, "ARTWORK", nil, 4), t
	t:SetSize(14,16)
	t:SetAtlas("bags-greenarrow")
	t:SetPoint("BOTTOMRIGHT", -8, 7.5)
	t:Hide()
	s.Blip = t
	t = f2:CreateTexture(nil, "ARTWORK", nil, 4)
	t:SetAtlas("adventure-healthbar")
	t:SetPoint("BOTTOMRIGHT", -5, -5)
	t:SetTexCoord(30/89, 1, 0, 1)
	t:SetSize(48, 36)
	s.HealthFrameR = t
	t = f2:CreateTexture(nil, "ARTWORK", nil, 5)
	t:SetAtlas("adventures-tank")
	t:SetSize(20.53,22)
	t:SetPoint("BOTTOMLEFT", 4, 5)
	s.Role = t
	t = f2:CreateTexture(nil, "ARTWORK", nil, 6)
	t:SetAtlas("adventure_ability_frame")
	t:SetSize(26.72, 26)
	t:SetPoint("CENTER", s.Role, "CENTER", 0, -2)
	t, s.RoleB, ett[#ett+1] = f2:CreateTexture(nil, "ARTWORK", nil, 6), t, t
	t:SetPoint("TOPRIGHT", 0, 2)
	t:SetSize(24,25)
	t:SetAtlas("collections-icon-favorites")
	s.Favorite, s.Abilities, s.AbilitiesB = t, {}, {}
	for i=1,2 do
		t = f2:CreateTexture(nil, "ARTWORK", nil, 3)
		t:SetAtlas("adventure_ability_frame")
		t:SetSize(26.72, 26)
		t:SetPoint("CENTER", s.Portrait, "CENTER", cos(232-i*42)*30, sin(232-i*42)*30)
		t, ett[#ett+1], s.AbilitiesB[i] = f2:CreateTexture(nil, "ARTWORK", nil, 2), t, t
		t:SetSize(17, 17)
		t:SetPoint("CENTER", s.AbilitiesB[i], "CENTER", 0, 1)
		t:SetTexture("Interface/Icons/Temp")
		t:SetMask("Interface/Masks/CircleMaskScalable")
		s.Abilities[i] = t
	end
	ett[#ett+1] = s.HealthFrameR
	t = f:CreateTexture(nil, "HIGHLIGHT")
	t:SetTexture("Interface/Common/CommonRoundHighlight")
	t:SetTexCoord(0,58/64,0,58/64)
	t:SetPoint("TOPLEFT", s.Portrait, "TOPLEFT", -1, 1)
	t:SetPoint("BOTTOMRIGHT", s.Portrait, "BOTTOMRIGHT", 1,-1)
	s.Hi = t
	if not isTroop then
		t = f:CreateTexture(nil, "BORDER", nil, -1)
		t:SetAtlas("adventures-buff-heal-ring")
		local divC = CovenKit == "Kyrian" and 0x78c7ff or CovenKit == "Venthyr" and 0xcf1500 or CovenKit == "Necrolord" and 0x76c900 or 0x0058e6
		t:SetVertexColor(divC / 2^24, divC/256 % 256 / 255, divC%256/255)
		t:SetPoint("TOPLEFT", s.PortraitR, "TOPLEFT", -6, 6)
		t:SetPoint("BOTTOMRIGHT", s.PortraitR, "BOTTOMRIGHT", 6, -6)
		s.EC = t
	end
	s.ExtraTex = CreateObject("ObjectGroup", ett)
	f.GetInfo = FollowerButton_GetInfo
	f.GetFollowerGUID = FollowerButton_GetFollowerGUID
	return f
end
function Factory.FollowerList(parent)
	local f,t = CreateFrame("Frame", nil, parent)
	local s = CreateObject("Shadow", f)
	f:SetSize(320, 370)
	t = f:CreateTexture(nil, "BACKGROUND")
	t:SetAllPoints()
	t:SetAtlas("adventures-followers-bg")
	t = f:CreateTexture(nil, "BORDER")
	t:SetPoint("TOPLEFT")
	t:SetSize(320, 84)
	t:SetAtlas("adventures-followers-frame")
	t:SetTexCoord(0,1, 0, 50/311)
	t = f:CreateTexture(nil, "BORDER")
	t:SetPoint("BOTTOMLEFT")
	t:SetSize(320, 84)
	t:SetAtlas("adventures-followers-frame")
	t:SetTexCoord(0,1, 261/311,1)
	t = f:CreateTexture(nil, "BORDER")
	t:SetAtlas("adventures-followers-frame")
	t:SetPoint("TOPLEFT", 0, -84)
	t:SetPoint("BOTTOMRIGHT", 0, 84)
	t:SetTexCoord(0,1,50/311,261/311)

	t = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	t:SetText(FOLLOWERLIST_LABEL_TROOPS)
	t:SetPoint("TOPLEFT", 12, -14)
	s.troops = {}
	for i=1,2 do
		s.troops[i] = CreateObject("FollowerListButton", f, true)
		s.troops[i]:SetPoint("TOPLEFT", (i-1)*76+14, -35)
	end
	t = CreateObject("CommonHoverTooltip", CreateObject("InfoButton", f))
	t:SetPoint("TOPRIGHT", -12, -12)
	t.tooltipHeader = FOLLOWERLIST_LABEL_TROOPS
	t.tooltipText = COVENANT_MISSIONS_TUTORIAL_TROOPS
	s.TroopInfo = t

	t = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	t:SetText(COVENANT_MISSION_FOLLOWER_CATEGORY)
	t:SetPoint("TOPLEFT", 12, -110)
	s.companions = {}
	for i=1,24 do
		t = CreateObject("FollowerListButton", f, false)
		t:SetPoint("TOPLEFT", ((i-1)%4)*76+14, -math.floor((i-1)/4)*72-130)
		s.companions[i] = t
	end
	f:SetPoint("LEFT", UIParent, "LEFT", 20, 0)

	f.Refresh = FollowerList_Refresh
	f.SyncToBoard = FollowerList_SyncToBoard
	f.SyncXPGain = FollowerList_SyncXPGain
	f:SetScript("OnUpdate", FollowerList_OnUpdate)
	f:SetScript("OnShow", FollowerList_Refresh)
	f:Hide()
	return f
end
function Factory.InfoButton(parent)
	local f = CreateFrame("Button", nil, parent)
	f:SetSize(20, 20)
	f:SetNormalTexture("Interface/Common/Help-i")
	f:GetNormalTexture():SetTexCoord(0.2, 0.8, 0.2, 0.8)
	f:SetHighlightTexture("Interface/Common/Help-i")
	f:GetHighlightTexture():SetTexCoord(0.2, 0.8, 0.2, 0.8)
	f:GetHighlightTexture():SetBlendMode("ADD")
	f:GetHighlightTexture():SetAlpha(0.25)
	return f
end
function Factory.TexSlice(parent, layer,subLevel, tex,tW,tH, x0,x1,x2,x3, y0,y1,y2,y3, xS,yS, oT,oR,oB,oL, mL)
	local r, ni, t = CreateObject("ObjectGroup"), 1
	for i=1,yS == 0 and 3 or 9 do
		r[i] = parent:CreateTexture(nil, layer, nil, subLevel)
	end
	r:SetTexture(tex)

	x0,x1,x2,x3=x0/tW,x1/tW,x2/tW,x3/tW
	y0,y1,y2,y3=y0/tH,y1/tH,y2/tH,y3/tH
	if yS > 0 then
		t, ni = r[ni], ni + 1
		t:SetTexCoord(mL and x3 or x0, mL and x2 or x1, y0, y1)
		t:SetPoint("TOPLEFT", -oL, oT)
		t:SetSize(xS, yS)
		t, ni = r[ni], ni + 1
		t:SetTexCoord(x1, x2, y0, y1)
		t:SetPoint("TOPLEFT", xS-oL, oT)
		t:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", oR-xS, oT-yS)
		t, ni = r[ni], ni + 1
		t:SetTexCoord(x2, x3, y0, y1)
		t:SetPoint("TOPRIGHT", oR, oT)
		t:SetSize(xS, yS)
	end
	t, ni = r[ni], ni + 1
	t:SetTexCoord(mL and x3 or x0, mL and x2 or x1, y1, y2)
	t:SetPoint("TOPLEFT", -oL, oT-yS)
	t:SetPoint("BOTTOMRIGHT", parent, "BOTTOMLEFT", xS-oL, yS-oB)
	t, ni = r[ni], ni + 1
	t:SetTexCoord(x1, x2, y1, y2)
	t:SetPoint("TOPLEFT", xS-oL, oT-yS)
	t:SetPoint("BOTTOMRIGHT", -xS+oR, yS-oB)
	t, ni = r[ni], ni + 1
	t:SetTexCoord(x2, x3, y1, y2)
	t:SetPoint("TOPLEFT", parent, "TOPRIGHT", oR-xS, oT-yS)
	t:SetPoint("BOTTOMRIGHT", oR, yS-oB)
	if yS > 0 then
		t, ni = r[ni], ni + 1
		t:SetTexCoord(mL and x3 or x0, mL and x2 or x1, y2, y3)
		t:SetPoint("BOTTOMLEFT", -oL, -oB)
		t:SetSize(xS, yS)
		t, ni = r[ni], ni + 1
		t:SetTexCoord(x1, x2, y2, y3)
		t:SetPoint("BOTTOMLEFT", -oL+xS, -oB)
		t:SetPoint("TOPRIGHT", parent, "BOTTOMRIGHT", oR-xS, yS-oB)
		t, ni = r[ni], ni + 1
		t:SetTexCoord(x2, x3, y2, y3)
		t:SetPoint("BOTTOMRIGHT", oR, -oB)
		t:SetSize(xS, yS)
	end

	return r
end
function Factory.MissionToast(parent)
	local f, t = CreateFrame("Button", nil, parent)
	local sf = CreateObject("Shadow", f)
	f:SetSize(295, 40)
	f:SetFrameStrata("FULLSCREEN")
	f:SetHitRectInsets(-6, -6, -6, -6)
	f:RegisterForClicks("RightButtonUp")
	f:SetScript("OnUpdate", Toast_Animate)
	f:SetScript("OnClick", Toast_OnClick)
	f.Background = CreateObject("TexSlice", f, "BACKGROUND", 0, "Interface/LootFrame/LootToast",1024,256, 578,638,763,823, 0,3,69,0, 45,0, 5,0,5,0, true)
	t = f:CreateTexture(nil, "ARTWORK")
	t:SetAtlas("loottoast-sheen")
	t:SetBlendMode("ADD")
	t:SetSize(90, 38) -- 171,75
	t:SetPoint("LEFT", 20, -1)
	t, f.Sheen = f:CreateTexture(nil, "OVERLAY", nil, -2), t
	t:SetTexture("Interface/AchievementFrame/UI-Achievement-Alert-Glow")
	t:SetTexCoord(5/512, 395/512, 5/256, 167/256)
	t:SetPoint("BOTTOMLEFT", -35, -30)
	t:SetPoint("TOPRIGHT", 35, 30)
	t:SetBlendMode("ADD")
	t, f.PreGlow = CreateObject("RewardBlock", f, 32, 2), t
	t.Container:SetPoint("LEFT", 10, -1)
	for i=1,3 do
		local ti = t[i]
		ti.tooltipAnchor, ti.tooltipXO, ti.tooltipFXO = "ANCHOR_TRUE_LEFT", -34*i+28, 285-34*i
		ti.tooltipPostShow = MissionToast_CheckTooltip
		ti.isRetrospective, ti.ShowQuantityFromWidgetText = true, "Quantity"
		ti.Quantity:Hide()
	end
	t, sf.Rewards = f:CreateFontString(nil, "ARTWORK", "GameFontNormal"), t
	t:SetPoint("TOPLEFT", sf.Rewards.Container, "TOPRIGHT", 2, -2.25)
	t:SetPoint("TOPRIGHT", -10, -7)
	t:SetHeight(12)
	t:SetText("|cffff8000Legendary Mission")
	t, f.Header = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight"), t
	t:SetPoint("BOTTOMLEFT", sf.Rewards.Container, "BOTTOMRIGHT", 2, 2.25)
	t:SetPoint("BOTTOMRIGHT", -10, 7)
	t:SetHeight(12)
	t:SetText("Legendary Goat Rescue")
	t, f.Detail = f:CreateTexture(nil, "ARTWORK", nil, 0), t
	t:SetSize(28, 28)
	t:SetPoint("LEFT", 12, -1)
	t:SetTexture(1605024)
	t, f.Portrait = f:CreateTexture(nil, "ARTWORK", nil, 1), t
	t:SetSize(34,34)
	t:SetAtlas("adventurers-followers-frame")
	t:SetPoint("CENTER", f.Portrait, "CENTER")
	f.PortraitFrame = t

	f:Hide()
	return f
end
function Factory.IconButton(parent, sz, tex)
	local mb = CreateFrame("Button", nil, parent)
	mb:SetSize(sz, sz)
	mb:SetNormalTexture(tex or "Interface/Icons/Temp")
	mb:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square")
	mb:GetHighlightTexture():SetBlendMode("ADD")
	mb:SetPushedTexture("Interface/Buttons/UI-Quickslot-Depress")
	mb:GetPushedTexture():SetDrawLayer("OVERLAY")
	local t = mb:CreateTexture(nil, "ARTWORK")
	t:SetAllPoints()
	t:SetTexture(tex or "Interface/Icons/Temp")
	mb.Icon = t
	return mb
end
function Factory.SharedTooltipProgressBar()
	tooltipSharedPB = tooltipSharedPB or CreateObject("TooltipProgressBar")
	return tooltipSharedPB
end
function Factory.Shadow(t)
	if t ~= nil then
		local s = S[t] or {}
		S[t], S[s] = s, t
		return s
	end
end
