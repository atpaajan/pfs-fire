	MODULE TEMPS

	USE COMM
	USE	DROPS

	CONTAINS

	REAL FUNCTION Burning()
	
	REAL o2depl,co2prod,h2oprod
	REAL entrainment,water,watertofire,co2tofire,n2tofire,h2otofire
	REAL artofire
	REAL co2heat,n2heat,h2oheat,arheat,dropheat,boilheat,vaporheat
	REAL cliq,Lvap,cvap,Tboil
	REAL Tflame,c_eff
	INTEGER niter

	cliq=4190.
	Lvap=2.4e6	! keskim��r�inen arvo kun ollaan matalissa l�mp�tiloissa; pit�is muuttaa l�mp�tilariippuvaksi !
	cvap=2000.
	Tboil=373.

	o2depl=(Qdot*dt/deltaH)/fuelmolmass*o2moles 	! palon sy�m� happi mooleina aika-askeleessa
c	print "Oxygen depletion, moles in time step",o2depl
	entrainment=o2depl/o2conc		! paloon menev� kaasum��r� kuutioina
	water=sum(waterconc)			! t�ss� oletetaan ett� kaikkia fraktioita menee liekkiin; mutta meneek� raskaat pisarat ?
	watertofire=entrainment*water	! paloon menev� vesim��r� litroina (kiloina)
c	watertofire=0		!	piilopalo, ei pisaroita liekkiin...
	
c HUOM: vesim��r�� ei muuteta palon sy�m�n veden vuoksi: t�t� ei edes tarvitse tehd�, sill� liekiss� h�yrystyv� vesi
c kondensoituisi kumminkin uudelleen j��hdytty��n k�mp�n l�mp�tilaan	
	
c	print "o2depl,entrainment,watertofire (liters):",o2depl,entrainment,watertofire
	co2tofire=entrainment*co2conc		! kaasum��r�t mooleina
	n2tofire=entrainment*n2conc
	h2otofire=entrainment*Yconc
	artofire=entrainment*arconc
	co2prod=co2moles/o2moles*o2depl		!	t�ss� on oletettu ett� polttoaine on heptaani
	h2oprod=h2omoles/o2moles*o2depl

	Tflame=1900.	! alkuarvaus kelvinein�
	niter=5
	j=0
	do while (j<niter)
		co2heat=(co2tofire+co2prod)*54.3*(Tflame-Tgas)	! l�mmitykseen kuluva energia Jouleina
		n2heat=n2tofire*32.7*(Tflame-Tgas)
		h2oheat=(h2otofire+h2oprod)*41.2*(Tflame-Tgas)
		arheat=artofire*20.8*(Tflame-Tgas)
		dropheat=(Tboil-Tgas)*cliq*watertofire
		boilheat=watertofire*Lvap
		vaporheat=(Tflame-Tboil)*cvap*watertofire	
		c_eff=(co2heat+n2heat+h2oheat+arheat+dropheat+boilheat
	1		   +vaporheat)/(Tflame-Tgas)	! efektiivinen l�mp�kapasiteetti, J/K
		Tflame=Tgas+(Qdot*dt)/c_eff		! 
		j=j+1
c		print Tflame
	enddo
	Burning=Tflame

	END FUNCTION Burning	



	REAL FUNCTION DeltaTemp()
	
	REAL o2_capacity,n2_capacity,h2o_capacity,co2_capacity,ar_capacity
	REAL gas_capacity,cliq,rholiq
	REAL Qw_in,Qw_susp,Qgas,Qvap,Qfire,heatbalance
	REAL prevbalance,niter,small,lopeta
	REAL deltaT,step,apu,apu2,apu3,j,apu4
	REAL suspwater
	REAL phi,plo,deltap,Lvap
	REAL Qwall
	REAL sum_mass,ddt,evapaika
	REAL d3sum,d2sum
	INTEGER jj
	
	co2_capacity=37.1*co2conc*volume	! kaasun l�mmitys; l�mp�kapasiteetit 298 K:ssa
	h2o_capacity=33.6*Yconc*volume		! capacity-muuttuja yksikk� on J/K
	n2_capacity=29.1*n2conc*volume
	o2_capacity=29.4*o2conc*volume
	ar_capacity=20.8*arconc*volume
	gas_capacity=co2_capacity+h2o_capacity+n2_capacity
	1             +o2_capacity+ar_capacity
	cliq=4190.	! heat capacity of liquid water, J/(kg K)
	Lvap=2.4e6	! heat of vaporisation of water, J/kg
	rholiq=1000.
	evapfract=0.
	
c	lasketaan kaasussa leijuvan veden massa ja erotetaan se osuus joka tulee suuttimista
	
	suspwater=sum(waterconc)*volume
	suspwater=max(suspwater-flowrate*dt,0.)	! t�h�n sis�ltyy pikkisen approksimaatiota...
		
c	Qfire=Qdot*dt
	deltaT=0.0
	step=0.01
	
c	Merkkis��nt�: l�mp�virta k�mpp��n p�in on plusmerkkinen (jolloin my�s DeltaTemp > 0)
	
		Qfire=Qdot*dt		! palon luovuttama l�mp� k�mp�n kaasufaasiin
		Qw_in=flowrate*dt*cliq*(Twater-Tgas)		! suuttimista tulevan veden l�mmitys
		Qwall=heattrans*wallarea*(Twall-(Tgas+deltaT))*dt

		evapmass=0.
		dmass=0.
		j=1
		do while (j<nfract+1)
			dmass(j)=EvapRate(Fractlimit(j))
	1				*(dropconc(j)+1)*volume ! kg/s koko k�mp�lle
			tmax(j)=waterconc(j)*volume/dmass(j)		! maksimiaika jona riitt�� h�yrystett�v��
c			write(*,*) dmass(j),tmax(j)
			j=j+1
		enddo
		sum_mass=sum(dmass)
		apu2=EXP(18.3-(381644./(Tgas-4613.)))/760.*1.0e5/(Rgas*Tgas) ! osapaine
																	! bar -> Pa
		ddt=dt/10.
		if (sum_mass>0) then		! h�yrstyminen
c			write (*,*) 'evap'
			evapaika=0.
			merkki=0
			do while (evapaika<dt+ddt)
				evapaika=evapaika+ddt
				jj=1
				do while (jj<nfract+1)
					if (evapaika<tmax(jj)) then
						evapmass=evapmass+dmass(jj)*ddt
						merkki(jj)=evapaika		
					endif
					jj=jj+1
				enddo 
				apu=Yconc+(evapmass/0.018)/volume
				if (apu>apu2) then		! tultiin saturoituneen h�yryn rajalle
					evapaika=dt+ddt
				endif
			enddo
		else						! kondensaatio
c			write (*,*) 'cond'
			evapaika=0.
			merkki=0
			apu=sum(dmass)*ddt		! apu < 0
			apu2=Yconc*volume*0.018		! apu2 > 0
			do while (evapaika<dt+ddt)
				evapaika=evapaika+ddt
				if (abs(apu)<apu2) then
					evapmass=evapmass+apu
				endif
				merkki=evapaika
				if (abs(evapmass)>apu2) then	! tsekataan ett� kondensoituvaa h�yry� riitt��
					evapmass=apu2				! k�mpp� menee kuivaksi...
					merkki=evapaika-ddt+abs(apu)/apu2*ddt		!...t�ss� ajassa
					evapaika=dt+ddt
				endif
			enddo	
		endif
		
		Qvap=-evapmass*Lvap		! jos evapmass>0 niin kaasu j��htyy

	deltaT=(Qfire+Qvap+Qw_in+Qwall+deltahvent)
	1        /(gas_capacity+suspwater*cliq)


c	print "niter,deltat,evapmass:",niter,deltaT,evapmass
			
	j=1			! muutetaan pisarakonsentraatioita
	d3sum=0
	d2sum=0
c	print "evapmass",evapmass,merkki
	do while (j<nfract+1)
		dropconc(j)=dropconc(j)-merkki(j)*dmass(j)
	1				/((1./6.)*3.14159*rholiq*Fractlimit(j)**3)/volume	
		if (dropconc(j)<0) then
			dropconc(j)=0		! bugi ? (onko oikein)
c			print "j,dropconc(j),evapfract(j):",j,dropconc(j),evapfract(j)
		endif
		waterconc(j)=rholiq*dropconc(j)*(1./6.)*3.14159
	1				*Fractlimit(j)**3
c 		drops(i)(j)=waterconc(j)
		d3sum=d3sum+dropconc(j)*Fractlimit(j)**3
		d2sum=d2sum+dropconc(j)*Fractlimit(j)**2
		j=j+1
	enddo
c	write (*,*) 'i,sauter',i
	if (i<npnts+1) then
		Sauter(i)=d3sum/d2sum
	endif
	DeltaTemp=deltaT

	END FUNCTION DeltaTemp

	END MODULE TEMPS