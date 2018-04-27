
""" 
Set up the plot figures, axes, and items to be done for each frame.

This module is imported by the plotting routines and then the
function setplot is called to set the plot parameters.
    
""" 

from __future__ import absolute_import
from __future__ import print_function
import os
if os.path.exists('./1drad/_output'):
    qref_dir = os.path.abspath('./1drad/_output')
else:
    qref_dir = None
    print("Directory ./1drad/_output not found")


#--------------------------
def setplot(plotdata=None):
#--------------------------
    
    """ 
    Specify what is to be plotted at each frame.
    Input:  plotdata, an instance of clawpack.visclaw.data.ClawPlotData.
    Output: a modified version of plotdata.
    
    """ 


    from clawpack.visclaw import colormaps

    if plotdata is None:
        from clawpack.visclaw.data import ClawPlotData
        plotdata = ClawPlotData()


    plotdata.clearfigures()  # clear any old figures,axes,items data
    

    # Figure for pressure
    # -------------------

    plotfigure = plotdata.new_plotfigure(name='Pressure', figno=0)

    # Set up for axes in this figure:
    plotaxes = plotfigure.new_plotaxes()
    plotaxes.xlimits = 'auto'
    plotaxes.ylimits = 'auto'
    plotaxes.title = 'Pressure'
    plotaxes.scaled = True      # so aspect ratio is 1
    # plotaxes.afteraxes = addgauges

    # Set up for item on these axes:
    plotitem = plotaxes.new_plotitem(plot_type='2d_pcolor')
    plotitem.plot_var = 0
    plotitem.pcolor_cmap = colormaps.blue_yellow_red
    plotitem.add_colorbar = True
    plotitem.show = True       # show on plot?
    plotitem.pcolor_cmin = -20.0
    plotitem.pcolor_cmax = 20.0
    plotitem.amr_patchedges_show = [1,1,1]
    plotitem.amr_celledges_show = [0,0,0]
    # plotitem.amr_patchedges_show = [0,0,0]
    # plotitem.amr_celledges_show = [0,0,0]

    # Figure for u-velocity
    # -------------------

    plotfigure = plotdata.new_plotfigure(name='u-velocity', figno=1)

    # Set up for axes in this figure:
    plotaxes = plotfigure.new_plotaxes()
    plotaxes.xlimits = 'auto'
    plotaxes.ylimits = 'auto'
    plotaxes.title = 'u-velocity'
    plotaxes.scaled = True      # so aspect ratio is 1
    # plotaxes.afteraxes = addgauges

    # Set up for item on these axes:
    plotitem = plotaxes.new_plotitem(plot_type='2d_pcolor')
    plotitem.plot_var = 1
    plotitem.pcolor_cmap = colormaps.blue_yellow_red
    plotitem.add_colorbar = True
    plotitem.show = True       # show on plot?
    plotitem.pcolor_cmin = -5
    plotitem.pcolor_cmax = 5
    # plotitem.amr_patchedges_show = [1,1,1]
    # plotitem.amr_celledges_show = [1,0,0]
    plotitem.amr_patchedges_show = [0,0,0]
    plotitem.amr_celledges_show = [0,0,0]

    # Figure for v-velocity
    # -------------------

    plotfigure = plotdata.new_plotfigure(name='v-velocity', figno=2)

    # Set up for axes in this figure:
    plotaxes = plotfigure.new_plotaxes()
    plotaxes.xlimits = 'auto'
    plotaxes.ylimits = 'auto'
    plotaxes.title = 'v-velocity'
    plotaxes.scaled = True      # so aspect ratio is 1
    # plotaxes.afteraxes = addgauges

    # Set up for item on these axes:
    plotitem = plotaxes.new_plotitem(plot_type='2d_pcolor')
    plotitem.plot_var = 2
    plotitem.pcolor_cmap = colormaps.blue_yellow_red
    plotitem.add_colorbar = True
    plotitem.show = True       # show on plot?
    plotitem.pcolor_cmin = -5
    plotitem.pcolor_cmax = 5
    # plotitem.amr_patchedges_show = [1,1,1]
    # plotitem.amr_celledges_show = [1,0,0]
    plotitem.amr_patchedges_show = [0,0,0]
    plotitem.amr_celledges_show = [0,0,0]
    
    

    # Figure for scatter plot
    # -----------------------

    plotfigure = plotdata.new_plotfigure(name='scatter', figno=3)
    plotfigure.show = (qref_dir is not None)

    # Set up for axes in this figure:
    plotaxes = plotfigure.new_plotaxes()
    plotaxes.xlimits = [0,1.5]
    plotaxes.ylimits = [-2.,4.]
    plotaxes.title = 'Scatter plot'

    # Set up for item on these axes: scatter of 2d data
    plotitem = plotaxes.new_plotitem(plot_type='1d_from_2d_data')
    
    def p_vs_r(current_data):
        # Return radius of each grid cell and p value in the cell
        from pylab import sqrt
        x = current_data.x
        y = current_data.y
        r = sqrt(x**2 + y**2)
        q = current_data.q
        p = q[0,:,:]
        return r,p

    plotitem.map_2d_to_1d = p_vs_r
    plotitem.plot_var = 0
    plotitem.plotstyle = 'o'
    plotitem.color = 'b'
    plotitem.show = True       # show on plot?
    
    # Set up for item on these axes: 1d reference solution
    plotitem = plotaxes.new_plotitem(plot_type='1d_plot')
    plotitem.outdir = qref_dir
    plotitem.plot_var = 0
    plotitem.plotstyle = '-'
    plotitem.color = 'r'
    plotitem.kwargs = {'linewidth': 2}
    plotitem.show = True       # show on plot?
    plotaxes.afteraxes = "import pylab; pylab.legend(('2d data', '1d reference solution'))"
    

    #-----------------------------------------
    # Figures for gauges
    #-----------------------------------------
    plotfigure = plotdata.new_plotfigure(name='q1', figno=300, \
                    type='each_gauge')
    plotfigure.clf_each_gauge = True

    plotaxes = plotfigure.new_plotaxes()
    plotaxes.xlimits = 'auto'
    plotaxes.ylimits = 'auto'
    plotaxes.title = 'Pressure'
    plotitem = plotaxes.new_plotitem(plot_type='1d_plot')
    plotitem.plot_var = 0
    plotitem.plotstyle = 'b-'

    plotfigure = plotdata.new_plotfigure(name='q2', figno=400, \
                    type='each_gauge')
    plotfigure.clf_each_gauge = True

    plotaxes = plotfigure.new_plotaxes()
    plotaxes.xlimits = 'auto'
    plotaxes.ylimits = 'auto'
    plotaxes.title = 'u-velocity'
    plotitem = plotaxes.new_plotitem(plot_type='1d_plot')
    plotitem.plot_var = 1
    plotitem.plotstyle = 'b-'

    plotfigure = plotdata.new_plotfigure(name='q3', figno=500, \
                    type='each_gauge')
    plotfigure.clf_each_gauge = True

    plotaxes = plotfigure.new_plotaxes()
    plotaxes.xlimits = 'auto'
    plotaxes.ylimits = 'auto'
    plotaxes.title = 'v-velocity'
    plotitem = plotaxes.new_plotitem(plot_type='1d_plot')
    plotitem.plot_var = 2
    plotitem.plotstyle = 'b-'


    # Parameters used only when creating html and/or latex hardcopy
    # e.g., via clawpack.visclaw.frametools.printframes:

    plotdata.printfigs = True                # print figures
    plotdata.print_format = 'png'            # file format
    plotdata.print_framenos = 'all'          # list of frames to print
    plotdata.print_fignos = 'all'            # list of figures to print
    plotdata.html = True                     # create html files of plots?
    plotdata.html_homelink = '../README.html'   # pointer for top of index
    plotdata.html_movie = 'JSAnimation'      # new style, or "4.x" for old style
    plotdata.latex = False                   # create latex file of plots?
    plotdata.latex_figsperline = 2           # layout of plots
    plotdata.latex_framesperline = 1         # layout of plots
    plotdata.latex_makepdf = False           # also run pdflatex?
    plotdata.parallel = True                 # make multiple frame png's at once

    return plotdata

    
    
# To plot gauge locations on pcolor or contour plot, use this as
# an afteraxis function:

def addgauges(current_data):
    from clawpack.visclaw import gaugetools
    gaugetools.plot_gauge_locations(current_data.plotdata, \
         gaugenos='all', format_string='ko', add_labels=True)
