pico-8 cartridge // http://www.pico-8.com
version 33
__lua__
--dungen
--dungen
--by ashley pringle
cartdata("dungen")
debug=false
debugs=true

enums={}
--actor types
enums.crawler=-1
enums.player=1
enums.enemy=2
enums.item=3
enums.ladder=4

function _init()
	state=0
	timer=0
	changestate(state)
	score={0,0,0}
	
	--movement types
	enums.key=1
	enums.rand=2
	enums.auto=3
	
	--game states
	enums.title=1
	enums.options=2
	enums.game=3
	
	hud={}
	hud.bar={}
	hud.bar.x=12
	hud.bar.y=10
	hud.bar.w=100
	hud.bar.h=6
	hud.bar.c=8
	hud.score={}
	hud.score.x=12
	hud.score.y=4
	hud.hp={}
	hud.hp.x=100
	hud.hp.y=4
end

function makeactor(t,mt,s,x,y,w,h,sp,an)
	local actor={}
	actor.t=t
	actor.mt=mt
	actor.s=s
	actor.x=x
	actor.y=y
	actor.w=w or 1
	actor.h=h or 1
	actor.sp=sp or 1
	actor.an=an or 0
	actor.vec={0,0}
	actor.step=0
	--if actor.t==enums.player then
	--	actor.step=1
	--end
	actor.movex=0
	actor.movey=0
	actor.right=false--todo: get rid of this
	actor.weapon={}
	actor.weapon.equip=0x0
	actor.weapon.x=actor.x+actor.movex
	actor.weapon.xoff=-8
	add(actors,actor)
	return actor
end

function makefacade(x,y)
	local f={}
	f.x=x
	f.y=y
	add(facades,f)
end

function drawactor(a)
	pal(12,0)
	spr(a.s+a.weapon.equip*2+a.an*(timer/12)%2,a.x*8+a.movex*8,a.y*8-(a.h-1)*8+a.movey*8,a.w,a.h,a.right)
	--spr(a.s+a.weapon.equip*2+a.an*(timer/12)%2,a.x*8+a.movex*8,a.y*8-8+a.movey*8,a.w,a.h,a.right)
	if a.weapon.equip>0 then
		spr(a.s+a.weapon.equip*4+a.an*(timer/12)%2,a.x*8+a.weapon.xoff+a.movex*8,a.y*8-(a.h)*4+a.movey*8,a.w,a.h,a.right)
	end
	pal()
end

function drawfacade(f)
	spr(12,f.x*8,f.y*8)
end

--0=left,1=right,2=up,3=down
function direction(d)
	local dire={0,0}
	if d==0 then dire[1]=-1 end
	if d==1 then dire[1]= 1 end
	if d==2 then dire[2]=-1 end
	if d==3 then dire[2]= 1 end
	return dire
end

-- returns count of free spaces around a cell
-- -1=exit found
-- 0 - 4 = amount of adj spaces that are 0 or no-go
function checkneighbours(ch,x,y)
	local cell=mget(x,y)
--	if cell==ch or cell==17 or cell==19 then--if cell at centre of check is 0 or no-go, return 4
	if cell==ch or cell==17 then--if cell at centre of check is 0 or no-go, return 4
		return 4--if this cell is 0 or no-go, return highest adj count (4)
	elseif cell==18 then--18=exit found
		return -1
	end
	local adj=0
	local dire={}
	for a=0,3 do
		dire=direction(a)
		local cell=mget(x+dire[1],y+dire[2])
		if cell==ch--if adj cell is 0 or no-go, add 1 to return adj count
		or cell==17
--		or cell==19
		then
			adj+=1
		end
	end
	return adj
end

-- checks if a cell has any adjacent cells that are viable routes for crawler
-- if a neighbour cell has too many free spaces next to it (>1) then it is not a viable option, already traversed by crawler
-- returns # of vialbe routes
function checkstuck(ch,x,y)
	local routes=4
	for i=0,3 do
		local dire=direction(i)
		if checkneighbours(ch,x+dire[1],y+dire[2])>=2 then
			routes-=1
		end
	end
	return routes
end

function controlactor(a)
	if a.mt==enums.key then
		a.vec[1]=0 a.vec[2]=0
		if     btn(0) then a.vec[1]=-1
		elseif btn(1) then a.vec[1]= 1
		elseif btn(2) then a.vec[2]=-1
		elseif btn(3) then a.vec[2]= 1
		elseif btnp(5) then a.weapon.equip=bxor(a.weapon.equip,0x1)
		end
	elseif a.mt==enums.rand then
		a.vec=direction(flr(rnd(4)))
	elseif a.mt==enums.auto then
		a.vec[1]=0 a.vec[2]=0
		if a.step<#steps then
			if a.movex==0 and a.movey==0 then
				a.step+=1
				a.vec[1]=steps[a.step][1]
				a.vec[2]=steps[a.step][2]
			end
		end
	end
	if a.t==enums.crawler then
		local cn=checkneighbours(0,a.x+a.vec[1],a.y+a.vec[2])--check destination cell for amount of adjacent free spaces
		if cn==-1 then--exit found, add this final step, move to next pass (item creation?) and remove crawler
			add(steps,a.vec)
			pass+=1
			del(actors,crawler)
			crawler=nil
		elseif cn<2 then--there is 0 or 1 empty adjacent cells, move crawler to dest and set dest cell to 0 (free space)
			sfx(1)
			a.x+=a.vec[1]
			a.y+=a.vec[2]
			mset(a.x,a.y,0)
			if mget(a.x,a.y-1)==1 then--if the cell above the new free space is solid, make it into a wall cell
				mset(a.x,a.y-1,2)
			end
			a.step+=1
			if a.step>#steps then
				add(steps,a.vec)
	--		else
			--	steps[a.step]={a.vec[1],a.vec[2]}--can this cause problems? should we do {vec1,vec2}?
			end
		elseif checkstuck(0,a.x,a.y)<=0 then--if there are no vialbe routes, set cell to dead end (17)
			mset(a.x,a.y,17)
			a.step-=1--set step back to last step
			if a.step<=0 then--exit couldn't be found
				sfx(4)
				changestate(state)
			else
				sfx(3)
				a.x-=steps[a.step+1][1]--undo last move step so crawler goes backwards
				a.y-=steps[a.step+1][2]
				deli(steps)
			end
		end
	elseif a.t==enums.player then
		if a.movex==0 and a.movey==0 then
			if mget(a.x+a.vec[1],a.y+a.vec[2])==0 then
				a.x+=a.vec[1]
				a.y+=a.vec[2]
				a.movex=-a.vec[1]
				a.movey=-a.vec[2]
				if a.vec[1]>0 then
					a.right=true
						a.weapon.xoff=8
				elseif a.vec[1]<0 then
					a.right=false
					a.weapon.xoff=-8
				end
--		else
--			a.movex=0
--			a.movey=0
			end
		end
	elseif a.t==enums.enemy then
		if a.x==player.x and a.y==player.y then
--			del(actors,player)
		end
		if timer%a.sp==0 then
			if mget(a.x+a.vec[1],a.y+a.vec[2])==0 then
				a.x+=a.vec[1]
				a.y+=a.vec[2]
				a.movex=-a.vec[1]
				a.movey=-a.vec[2]
				if a.vec[1]>0 then
					a.right=true
				else
					a.right=false
				end
--			else
--				a.movex=0
--				a.movey=0
			end
		end
	elseif a.t==enums.item then
		if player.x==a.x and player.y==a.y then
			sfx(5)
			score[a.s-48]+=1
			del(actors,a)
		end
	elseif a.t==enums.ladder then
		if player.x==a.x and player.y==a.y then
			if #transitions==0 then
				sfx(6)
				maketransition(64)
			end
			--changestate(state)
		end
	end
	if a.movex<0 then
		if a.movex<-0.1 then
			a.movex+=1/a.sp
		else
			a.movex=0
		end
	elseif a.movex>0 then
		if a.movex>0.1 then
			a.movex-=1/a.sp
		else
			a.movex=0
		end
	end
	if a.movey<0 then
		if a.movey<-0.1 then
			a.movey+=1/a.sp
		else
			a.movey=0
		end
	elseif a.movey>0 then
		if a.movey>0.1 then
			a.movey-=1/a.sp
		else
			a.movey=0
		end
	end
end

function damageactor(a,d)

end

function _update()
	if timer%speed==0 then
		if pass==1 then
			foreach(actors,controlactor)
		elseif pass==2 then
			for b=0,15 do
				for a=0,15 do
					local cell=mget(a,b)
--					if cell==17 or cell==19 then
					if cell==17 then
						if rnd(1)<0.05 then
							makeactor(enums.item,0,49,a,b)
						elseif rnd(1)<0.05 then
							makeactor(enums.item,0,50,a,b)
						elseif rnd(1)<0.05 then
							makeactor(enums.item,0,51,a,b)
						elseif rnd(1)<0.05 then
							makeactor(2,enums.rand,65,a,b,1,2,20,1)
						end
						mset(a,b,0)
					elseif cell==2 then
						if checkneighbours(0,a,b)==4 then
							if rnd(1)<0.5 then
								mset(a,b,0)
							end
						end
					elseif cell==18 then
						mset(a,b,0)
						mset(a,b+1,0)
						makeactor(4,0,28,a,b,1,2)
					end
					cell=mget(a,b)
					if cell==2 or cell==1 then
						if a!=spawn.x or b!=spawn.y then
							makefacade(a,b-1)
						else
							mset(a,b,0)
							if mget(a,b-1)==1 then
								mset(a,b-1,2)
							end
						end
					end
					
				end
			end
			player=makeactor(enums.player,mget(127,31),97,spawn.x,spawn.y,1,2,8,1)
			sfx(2)
			pass+=1
		elseif pass==3 then
			foreach(actors,controlactor)
			foreach(transitions,controltransition)
			if btnp(4) then
				--changestate(state)
			end
		end
	end
	timer+=1
	if debug or debugs then
		debug_u()
	end
end

function _draw()
	cls()
	camera(cam[1],cam[2])
--	pal(5,1)
--	pal(1,3)
	map(0,0,0,0,16,16)
	foreach(actors,drawactor)
	foreach(facades,drawfacade)
	foreach(transitions,drawtransition)
	if debug then
		for a=1,#debug_l do
			print(debug_l[a],cam[1]+0,cam[2]+(a-1)*6,8)
		end
		for a=1,#actors do
			local ac=actors[a]
			rect(ac.x*8,ac.y*8,ac.x*8+8,ac.y*8+8,8)
		end
	end
	if debugs then
		for a=1,#debug_s do
			dsc=8
			if crawler then
				if crawler.step==a then
					dsc=10
				end
			elseif player then
				if player.step==a then
					dsc=12
				end
			end
			print(a.." "..debug_s[a],cam[1]+flr(a/22)*35,cam[2]+(a-1)*6-flr(a/22)*127,dsc)
		end
	end
end

function clamp(v,mi,ma,h)
	if h then
		if v<mi then v=mi
		elseif v>ma then v=ma
		end
	else
		if v<mi then v=ma
		elseif v>ma then v=mi
		end
	end
	return v
end

function rndint(n)
	return	flr(rnd(n))
end

function changestate(s)
	state=s
	timer=0
	speed=1
	pass=1
	steps={}
	debug_l={}
	debug_s={}
	cam={0,0}
	cam.shake=0
	
	actors={}
	facades={}
	transitions={}
	introtext={}
	titletimer=0
	spawn={}
	
	music(-1)
	reload()
	if state==0 then
		spawn.x,spawn.y=rndint(16),rndint(16)
		crawler=makeactor(-1,2,0,spawn.x,spawn.y)
		local ex,ey=rndint(16),rndint(16)
		mset(ex,ey  ,18)
		mset(ex,ey-1,2)
	end
end

function maketransition(n)
	local t={}
	t.delta=timer
	t.blocks={}
	for a=1,n do
		add(t.blocks,false)
	end
	add(transitions,t)
end

function controltransition(t)
	local d=timer-t.delta
	if d>=#t.blocks-1 then
		transitions={}
		changestate(state)
	end
	--if d%3==0 then
	local r=rndint(#t.blocks)+1
	while t.blocks[r]==true do
		r=rndint(#t.blocks)
	end
	t.blocks[r]=true
	--end
end

function drawtransition(t)
	for a=0,#t.blocks-1 do
		if t.blocks[a+1]==true then
			--rectfill(a*32,flr(a/4)*32,a*32+32,flr(a/4)*32+32,14)
			local mult=128/sqrt(#t.blocks)
			local x=(a%sqrt(#t.blocks))*mult
			local y=flr(a/sqrt(#t.blocks))*mult
			rectfill(x,y,x+mult,y+mult,0)
		end
	end
end

function debug_u()
	debug_l[1]=timer
	debug_l[2]="mem="..stat(0)
	debug_l[3]="cpu="..stat(1)
	debug_l[4]="actors:"..#actors
	if player!=nil then
		debug_l[5]="plr x:"..player.x
		debug_l[6]="plr y:"..player.y
		debug_l[7]="plr step:"..player.step
	end
--	debug_l[7]=mget(127,31)
	debug_l[8]="tr:"..#transitions
	debug_l[9]="sc1:"..score[1]
	debug_l[10]="sc2:"..score[2]
	debug_l[11]="sc3:"..score[3]
	debug_l[12]="steps: "..#steps
	debug_l[13]="spawn: "..spawn.x.." "..spawn.y

--	debug_l[5]="step:"..actors[1].step

	if debugs then
		debug_s={}
		for a=1,#steps do
			debug_s[a]=steps[a][1].." "..steps[a][2]
		end
	end
end
__gfx__
00000000313313313133133100000007666666666666666666666666000000006666666600000000111111115555555500000000111111111111111100000000
00000000111111111111111170070000565565565655655616116116000000005655655600000000313313311511511500000000313313313133133100000000
00000000133133130202020200070000666666666666666666666666000000006666666600000000111111115555555500000000111111111111111100000000
00000000111111110020202000777777655655656556556561161161000000006556556500000000133133135115115111111111202020201331331300000000
00000000313313310202020207007007666666666666666666666666000000006666666600000000111111115555555531331331020202021111111100000000
00000000111111112020202000777077505050505655655650505050000000005151515100000000202020201020102011111111202020203133133100000000
00000000133133130202020000070070505050506666666650505050000000005151515100000000020202022010201013313313020202021111111100000000
00000000111111112020202007777770000000006556556544444444000000004444444400000000202020201020102011111111202020201331331300000000
00000000000000001111111100000000cccccccc002222006666666600000000494444948888888800d00d000d0000d000000000000000001111111100000000
008888000000000012222221000000000c00c00c0020020056556556000000004994499408008008002dd20002dddd2000000000000000223133133100000000
08000000000000001000000100000000cccccccc0022220066666666000000009449944988888888012222101222222100000000000022051111111100000000
00888000000000001d0000d100000000c00c00c00020020065565565000000004444944980080080012002101200002100000000002205052020202000000000
000008000008000012dddd2100090000cccccccc002222006666666600000000444499998888888801222210122222210d0000d0220505050202020200000000
000008000000000012222221000000000c00c00c0020020000000000000000009449994408008008012002101200002102dddd20050505052020202000000000
08888000000000001111111100000000cccccccc0000000000000000000000009994494488888888011111101111111102222220050505000202020200000000
00000000000000002222222200000000c00c00c00000000000000000000000009944449980080080022222202222222202000020050500002020202000000000
00000000888888887777777733333333888888880404040400000000555555558888888802020202000000004944449412dddd21111111110000000000000000
00000000989989980700700703003003989989984040404000000000151151159899899820202020000000004994499412222221122121210000000000000000
000000008888888877777777333333338888888894499449000000005555555588888888888888880000000094499449120000211dd2d2d10000000000000000
00000000899899897007007030030030899899894444944900000000511511518998998989989989000000004444944912dddd2111dddd110000000000000000
0000000088888888777777773333333388888888444499990000000055555555888888888888888800000000444499991222222112dddd210000000000000000
000000009899899860606060404040409899899894499944000000001010101098998998989989980000000094499944120000211d1d1dd10000000000000000
00000000888888886060606040404040888888889994494400000000010101018888888888888888000000009994494411111111111111110000000000000000
00000000899899890000000000000000899899899944449900000000101010108998998989989989000000009944449922222222222222220000000000000000
000000000000333000aaa00000000000020202029944449999444499000000b0000000002222222200000000000000000000bbb0000000000000000000000000
000000000003bbb007999a000000000020202020999449999994499900888b8000000000200000000099900000000000000b0300000000000000000000000000
00000000003b0300a97aa9a00eee0000944994499449944994499449087e88880000000020000050097aa9000000000000b00300000000000000000000000000
0000000000b003e09779aa900888eeee44449449444494494444944908e8888800000000200050509779aa900000000000b00880000000000000000000000000
000000000ee0288e9aa9aa90080888884444999944449999444499990888888800000000205050509a9a9a9000000000088028e8000000000000000000000000
00000000e88e887809aaa900088808089449994494499944944999440888888800000000205050009aa9aa900000000087e82888000000000000000000000000
0000000087880880009990000000000099944944999449449994494400888880000000002050000009aaa900000000008e880880000000000000000000000000
00000000088000000000000000000000994444999944449999444499000000000000000022222222009990000000000008800000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000fffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000fffff000cfccf0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000cfccf000cfccf0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000cfccf000fcfff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000fcfff0000ff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000ff0000ffffff5500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000fffff50f005000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000f0050005f0fff50500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000f0fff5050005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000f005000500fff50000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000f0fff5050f00005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000f0000500f00000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000f000050f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000f0000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000080000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000008000003300000000800000330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000033000bbbbb30000033000bbbbb3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbbbb30004444500bbbbb300044445000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000044445000141450004444500014145000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000014145000444450001414500044445000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000044445000044000004444500004400000000000000005000000000000000000000000000000000000000000000000000000000000000000000000000
00000000004400004bbbb355004400004bbbb3550000000055555664000000000000000000000000000000000000000000000000000000000000000000000000
000000000bbbb35040bbb3050bbbb35000bbb3050000000000005000000000000000000000000000000000000000000000000000000000000000000000000000
0000000040bbb30540bbb30540bbb30500bbb3050000506400000000000000000000000000005064000000000000000000000000000000000000000000000000
0000000040bbb305002e210000bbb305002e21000000060000000000000000000000000000000600000000000000000000000000000000000000000000000000
00000000402e210500bbb300002e210500bbb3000000505000000000000000000000000000005050000000000000000000000000000000000000000000000000
0000000040bbb3050400005000bbb305040000500005000000000000000000000000000000050000000000000000000000000000000000000000000000000000
00000000040000500400000504000050040000050050000000000000000000000000000000500000000000000000000000000000000000000000000000000000
00000000040000504000000004000050400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000040000500000000004000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0000000000000000000000000000000000000000000000000200000000000000000000000002000000000002000000000000000002020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003
__sfx__
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000453004530045300453000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
000200003275032750327500000038740387003873000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000441004410044100441000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000800000933009330043000433004330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000500000975008750337503475036740387303972000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00070000077100d6400e000077100b6300e000067100a6200e0000871009610000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
