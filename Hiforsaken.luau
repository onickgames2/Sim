return {
	FreeTesting = true, -- if set to false, only testers will be able to join your game
	GamemodeSelection = true, -- random selection of gamemodes
	NotAllowedKickMsg = "game currently shut down, will be back soon",
	FreeVIP = true, -- gives everyone vip priveledges without buying the gamepass
	PreferCustomRankNames = false,
	UpdateLogOnce = true,
	DefaultAmbience = "rbxassetid://129991463413097",
	DefaultEmote = "rbxassetid://0",

	-- Como o jogo é de grupo, coloque seu UserId direto (nao use game.CreatorId)
	ManualRanks = {
		[SEU_USERID] = 255,
		-- [OUTRO_USERID] = 200,
	},

	CustomTitles = {
		[SEU_USERID] = "[OWNER]",
		-- [OUTRO_USERID] = "[Developer]",
	},
}
