# References

[Ripple Simulator](../index.md) / References

## Wave physics

**Falcon, E., and Mordant, N. (2022).** “Experiments in Surface Gravity–Capillary
Wave Turbulence.” *Annual Review of Fluid Mechanics*, 54, 1–25.
[Published review](https://doi.org/10.1146/annurev-fluid-021021-102043).
Section 2 gives the inviscid gravity–capillary dispersion relation and defines
the crossover where gravity and surface tension contribute equally.

**Sakai, K., Tachibana, K., Mitani, S., and Takagi, K. (2003).**
“Laser excitation of high-frequency capillary waves.” *Journal of Colloid
and Interface Science*, 264(2), 446–451.
[Published paper](https://doi.org/10.1016/S0021-9797(03)00448-X).
Theoretical and experimental study of capillary waves excited by periodic
radiation pressure, including their propagation away from the forcing region.

**Bobb, L. C., Ferguson, G., and Rankin, M. (1979).** “Capillary wave
measurements.” *Applied Optics*, 18(8), 1167–1171.
[Published paper](https://doi.org/10.1364/AO.18.001167).
Wind-driven tank measurements of wave height, slope, and frequency content.
The reported crest-to-trough heights depend on the imposed wind speed and
are not a calibration of drop-generated ring waves.

**Crapper, G. D. (1957).** “An exact solution for progressive capillary waves
of arbitrary amplitude.” *Journal of Fluid Mechanics*, 2(6), 532–540.
[Published paper](https://doi.org/10.1017/S0022112057000348).
An exact nonlinear pure-capillary wave family. Its limiting ratio of
crest-to-trough height to wavelength is distinct from the small-slope
criterion used for linear disturbances.

**Slavchov, R. I., Peychev, B., and Ismail, A. S. (2021).** “Characterization
of capillary waves: A review and a new optical method.” *Physics of Fluids*,
33(10), 101303. [Published paper](https://doi.org/10.1063/5.0066759).
Review of optical methods for measuring capillary wavelengths and decay,
including the influence of surface elasticity. Its optical method determines
relative amplitudes; it does not provide an absolute calibration for the
simulator's impulsive source.

**Airy, G. B. (1845).** “Tides and Waves.” *Encyclopaedia Metropolitana*,
vol. 5, pp. 241–396. [Digitized original](https://books.google.com/books?id=41dSAAAAcAAJ).
Classical treatment of tides and small-amplitude gravity waves.
Section IV.1, pp. 284–285, develops the small-disturbance approximation by
neglecting terms beyond first order.

**Massachusetts Institute of Technology (MIT).** “Linearized (Airy) Wave Theory.”
*Fluid Mechanics Modules*, Water Waves.
[University teaching notes](https://web.mit.edu/fluids-modules/www/potential_flows/LecturesHTML/lec19bu/node3.html).
Derivation of the linear gravity-wave approximation from small surface
displacement and slope.

**Toffoli, A., Monbaliu, J., Onorato, M., Osborne, A. R., Babanin, A. V., and
Bitner-Gregersen, E. (2007).** “Second-Order Theory and Setup in Surface Gravity
Waves: A Comparison with Experimental Data.” *Journal of Physical Oceanography*,
37(11), 2726–2739. [Published paper](https://doi.org/10.1175/2007JPO3634.1).
Section 2a relates the second-order harmonic amplitude to wave steepness and
water depth. The deep-water result supplies a gravity-wave reference for the
small-slope operating criterion.

**Akers, B., and Nicholls, D. P. (2013).** “Spectral Stability of Deep Two-Dimensional
Gravity-Capillary Water Waves.” *Studies in Applied Mathematics*, 130(2), 81–107.
[Published paper](https://doi.org/10.1111/j.1467-9590.2012.00574.x).
Nonlinear free-surface equations, capillary curvature, and the dependence of
weakly nonlinear gravity-capillary expansions on resonant interactions.

**Armaroli, A., Eeltink, D., Brunetti, M., and Kasparian, J. (2018).**
“Viscous damping of gravity-capillary waves: Dispersion relations and nonlinear
corrections.” *Physical Review Fluids*, 3, 124803.
[Published paper](https://doi.org/10.1103/PhysRevFluids.3.124803).
Peer-reviewed analysis of viscous dispersion and the limits of common
approximations. The simulator uses a linear response; it does not implement
the paper's nonlinear corrections.

**Denner, F. (2016).** “Frequency dispersion of small-amplitude capillary waves
in viscous fluids.” *Physical Review E*, 94, 023110.
[Published paper](https://doi.org/10.1103/PhysRevE.94.023110).
Peer-reviewed treatment of viscous capillary-wave dispersion and the transition
between oscillatory and nonoscillatory behavior.

**Patibandla, R., Basak, S., Dasgupta, R., and Roy, A. (2023).**
“Surface and internal gravity waves on a viscous liquid layer: Initial-value
problems.” *International Journal of Multiphase Flow*, 169, 104592.
[Published paper](https://doi.org/10.1016/j.ijmultiphaseflow.2023.104592).
Peer-reviewed initial-value analysis, including surface and vorticity modes.
Its broader stratified and finite-depth problems are not implemented here.

## Impulsive excitation and ring waves

**Naugol'nykh, K. A., Puchenkov, O. V., Zosimov, V. V., and Pashin, A. E. (1993).**
“Surface motion induced by the interaction of pulsed laser radiation with highly
absorbing dielectric fluids.” *Journal of Fluid Mechanics*, 250, 385–421.
[Published paper](https://doi.org/10.1017/S0022112093001508).
Theory and experiments on pressure-impulse excitation, including linear
gravity-capillary waves in weakly and strongly viscous fluids. The applied
loading originates from laser recoil rather than a falling drop.

**Tjan, K. K., and Phillips, W. R. C. (2007).**
“On impulsively generated inviscid axisymmetric surface jets, waves and drops.”
*Journal of Fluid Mechanics*, 576, 377–403.
[Published paper](https://doi.org/10.1017/S0022112007004648).
Gaussian impulsive velocity potentials and their nonlinear inviscid evolution.
The Gaussian initial condition supports the source formulation; the nonlinear
jet and droplet dynamics are outside the simulator's linear viscous model.

**Craeye, C., Sobieski, P. W., Bliven, L. F., and Guissard, A. (1999).**
“Ring-Waves Generated by Water Drops Impacting on Water Surfaces at Rest.”
*IEEE Journal of Oceanic Engineering*, 24(3), 323–332.
[Published paper](https://doi.org/10.1109/48.775294).
Optical measurements of ring-wave slopes, elevations, wavelengths, and energy
for 2.2- and 2.8-mm drops impacting fresh and salt water.

**Le Méhauté, B. (1988).** “Gravity–capillary rings generated by water drops.”
*Journal of Fluid Mechanics*, 197, 415–427.
[Published paper](https://doi.org/10.1017/S0022112088003301).
Linear theory of dispersive gravity–capillary rings generated by impulsive
loading, including viscous dissipation.

**Contreras, R. F., and Plant, W. J. (2006).**
“Surface effect of rain on microwave backscatter from the ocean: Measurements
and modeling.” *Journal of Geophysical Research: Oceans*, 111, C08019.
[Published paper](https://doi.org/10.1029/2005JC003356).
Momentum-based ring-wave modeling compared with measured drop-generated
profiles. The comparison uses an effective impact footprint, a generation
delay, and fitted dissipation; these are distinct from molecular viscosity.

**Sobieski, P., Craeye, C., and Bliven, L. F. (2009).**
“A relationship between rain radar reflectivity and height elevation variance
of ringwaves due to the impact of rain on the sea surface.” *Radio Science*,
44(3). [Published paper](https://doi.org/10.1029/2008RS003880).
Sections 3.1–3.3 relate measured ring-wave energy to drop momentum and
distinguish individual impacts from the statistics of a rain field.

<a id="reflecting-boundaries"></a>

## Wave reflection

**Dean, R. G., and Dalrymple, R. A. (1991).**
*Water Wave Mechanics for Engineers and Scientists.* Advanced Series on
Ocean Engineering, Vol. 2. World Scientific.
[Book](https://doi.org/10.1142/1232).
Textbook treatment of standing waves at an impermeable vertical wall and
partial reflection in Sections 4.4 and 4.6. The partial-reflection discussion
distinguishes reflected amplitude from phase change; this simulator uses a
real, nonnegative coefficient with zero phase change.

**Daqaq, M. F., Xu, Y., and Lacarbonara, W. (2017).**
*Nonlinearity of Finite-Amplitude Sloshing in Rectangular Containers.*
Journal of Applied Mechanics, 84(3), 031002.
[DOI: 10.1115/1.4035363](https://doi.org/10.1115/1.4035363).
Peer-reviewed study using an inviscid rectangular-container model with slipping
contact lines and a 90-degree contact angle, supporting the stated contact-line
idealization.

**Qin, H., Shen, J., and Chen, X. (2011).**
“A free surface frequency domain Green function with viscous dissipation and
partial reflections from side walls.” *Journal of Marine Science and
Application*, 10(3), 259–264.
[Published paper](https://doi.org/10.1007/s11804-011-1067-0).
Peer-reviewed use of weighted image sources for partial side-wall reflection.
The paper's frequency-domain visco-potential formulation differs from the
initial-value viscous response used here.

## Numerical interpolation

**Berrut, J.-P., and Trefethen, L. N. (2004).**
“Barycentric Lagrange Interpolation.” *SIAM Review*, 46(3), 501–517.
[Published paper](https://doi.org/10.1137/S0036144502417715).
The barycentric formula and first-kind Chebyshev weights support the piecewise
wavenumber interpolation used to prepare reflecting-mode response tables.

## Material properties

**International Association for the Properties of Water and Steam (IAPWS). (2011).**
*Supplementary Release on Properties of Liquid Water at 0.1 MPa*,
SR6-08(2011).
[Official release](https://iapws.org/technical-guidance/release/LiquidWater.download).
Scientific reference correlations for density and viscosity at the specified
pressure. The app restricts the temperature range to 0–40 °C.

**International Association for the Properties of Water and Steam (IAPWS). (2014).**
*Revised Release on Surface Tension of Ordinary Water Substance*, R1-76(2014).
[Official release](https://iapws.org/documents/release/Surf-H2O.download).
Scientific reference correlation for the liquid–vapor surface tension.

**Shin-Etsu Chemical Co., Ltd.** *KF-96 Silicone Fluid: Performance Test Results*.
[Manufacturer technical data](https://www.shinetsusilicone-global.com/catalog/pdf/kf96_e.pdf).
Typical product properties for the specified silicone-fluid grades, including
viscosity, specific gravity, surface tension, and qualifications concerning
temperature and shear behavior.

**Nayik, G. A., Dar, B. N., and Nanda, V. (2018).**
“Rheological behavior of high altitude Indian honey varieties as affected by
temperature.” *Journal of the Saudi Society of Agricultural Sciences*, 17(3),
323–329. [Published paper](https://doi.org/10.1016/j.jssas.2016.07.003).
Table 2 supplies the acacia-honey viscosity of 0.27 Pa s at 30 °C.

**Meli (2022).** *Acacia honey technical sheet*, April 7.
[Manufacturer's data](https://meli.be/app/uploads/2024/09/1.-Technical-sheet-ACACIA-HONEY-ENG-EUR-PALL-07042022-REF-1024988.pdf).
Reports an acacia-honey density range of 1398–1445 kg/m³ across moisture and
temperature conditions. The commercial product differs from Nayik et al.'s
sample; its density supports a representative approximation.

**Tyowua, A. T., Echendu, A. M., and Adejo, S. O. (2023).**
“Influence of particle fluorination on the stability of honey foam.”
*Frontiers in Soft Matter*, 3, 1163393.
[Published paper](https://doi.org/10.3389/frsfm.2023.1163393).
Table 1 supplies the representative honey surface tension at 30 ± 2 °C and
the strongly viscous reference fluid used in numerical verification.

**Townsend, A. K., and Wilson, H. J. (2016).**
“The fluid dynamics of the chocolate fountain.” *European Journal of Physics*,
37, 015803. [Published paper](https://doi.org/10.1088/0143-0807/37/1/015803).
Peer-reviewed comparison of Newtonian and non-Newtonian fountain models.
Table 1 supplies the representative density for the molten-chocolate preset.

**Keijbets, E. L. (2009).** *Solid mould surface characteristics in relation
to chocolate adhesion and the influence of processing conditions.* PhD thesis,
University of Leeds.
[University repository](https://etheses.whiterose.ac.uk/id/eprint/12740/).
Section 4.3.1.2 and Figure 4.1 report liquid-chocolate surface tensions at
50 °C, measured with a Wilhelmy plate. These measurements support the preset's
representative surface-tension approximation; they concern different formulations.

**Kumbár, V., Kouřilová, V., Dufková, R., Votava, J., and Hřivna, L. (2021).**
“Rheological and Pipe Flow Properties of Chocolate Masses at Different
Temperatures.” *Foods*, 10(11), 2519.
[Published paper](https://doi.org/10.3390/foods10112519).
Experimental evidence of shear-dependent, thixotropic, and yield-stress behavior
in molten chocolate, supporting the stated limits of a constant-viscosity model.

**TA Instruments.** “Evaluating the Flow Behavior of Molten Chocolate,” RH113.
[Manufacturer application note](https://www.tainstruments.com/pdf/literature/RH113.pdf).
Table 1 and Figure 8 illustrate shear-dependent chocolate viscosity and the
limits of substituting one apparent viscosity for a complete constitutive law.

**Toker, O. S., et al. (2017).** “Investigating the effect of production process
of ball mill refiner on some physical quality parameters of compound chocolate:
response surface methodology approach.” *International Journal of Food Science
and Technology*, 52(3), 788–799.
[Published paper](https://doi.org/10.1111/ijfs.13336).
Figure 5 supplies the approximate compound-chocolate viscosity at 60 °C,
measured at a shear rate of 50 s⁻¹. Table 3 and the methods describe the
Newtonian fit over 0.1–100 s⁻¹ at 40 °C.

**IUPAC.** “Newtonian fluid.” *Compendium of Chemical Terminology (Gold Book)*.
[Terminology reference](https://goldbook.iupac.org/terms/view/N04138).
Defines the Newtonian relation between shear stress and velocity gradient.

**Sahasrabudhe, S. N., Rodriguez-Martinez, V., O’Meara, M., and Farkas, B. E. (2017).**
“Density, viscosity, and surface tension of five vegetable oils at elevated
temperatures: Measurement and modeling.” *International Journal of Food
Properties*, 20(sup2), S1965–S1981.
[Published paper](https://doi.org/10.1080/10942912.2017.1360905).
Tables 2, 4, and 6 provide the room-temperature olive-oil properties.

## MATLAB documentation

**MathWorks.** [MATLAB DocMaker](https://github.com/mathworks/docmaker).
Documentation authoring and conversion software used to produce this manual.
The distributed HTML can be read without installing DocMaker.

**MathWorks.** [Display Custom Documentation](https://www.mathworks.com/help/matlab/matlab_prog/display-custom-documentation.html).
Official guidance for integrating custom documentation with MATLAB Help.

See [Third-party notices](notices.md) for the licenses of distributed
documentation resources.
