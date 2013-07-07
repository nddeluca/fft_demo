require('lib/setup')
Galactic = require('galactic')
Spine = require('spine')
$ = jQuery

class App extends Spine.Controller
  constructor: ->
    super

    @fits_loaded = false
    @psf_loaded = false

    fits_xhr = new XMLHttpRequest()
    fits_xhr.open('GET', 'images/test_cutout.fits')
    fits_xhr.responseType = 'arraybuffer'
    fits_xhr.onload = $.proxy(@set_up_fits, this, fits_xhr)

    psf_xhr = new XMLHttpRequest()
    psf_xhr.open('GET', 'images/test_psf.fits')
    psf_xhr.responseType = 'arraybuffer'
    psf_xhr.onload = $.proxy(@set_up_psf, this, psf_xhr)

    @render()
    xhr.send()

  set_up_fits: (xhr) ->
    file = new FITS.File(xhr.response)
    image = file.getDataUnit()
    image.getFrame()

    @fits_image = new Galactic.Image(width: image.width, height: image.height)

    l = @fits.width*@fits.height
    while l--
      @fits.data[l] = image.data[l]

    @fits_loaded = true

    if @psf_loaded
      @set_up_app()

  set_up_psf: (xhr) ->
    file = new FITS.File(xhr.response)
    image = file.getDataUnit()
    image.getFrame()

    @psf_image = new Galactic.Image(width: image.width, height: image.height)

    l = @psf.width*@psf.height
    while l--
      @psf.data[l] = image.data[l]

    @psf_loaded = true

    if @fits_loaded
      @set_up_app()

  set_up_displays: (width,height) ->

    @model_display = new Galactic.Display(container: 'model', width: width, height: height)
    @psf_display = new Galactic.Display(container: 'psf', width: width, height: height)

    @padded_model_display = new Galactic.Display(container: 'padded-model', width: width, height: height)
    @padded_psf_display = new Galactic.Display(container: 'padded-psf', width: width, height: height)

    @fft_model_display = new Galactic.Display(container: 'fft-model', width: width, height: height)
    @fft_psf_display = new Galactic.Display(container: 'fft-psf', width: width, height: height)

    @convolution_display = new Galactic.Display(container: 'convolution', width: width, height: height)

    @padded_inverse_display = new Galactic.Display(container: 'padded-inverse', width: width, height: height)

    @inverse_display = new Galactic.Display(container: 'inverse', width: width, height: height)

  set_up_app: ->
    width = 400
    height = Math.round((@fits_image.height/@fits_image.width)*width)

    @set_up_displays(width,height)



    @orig_formatter = new Galactic.ImageFormatter(input: image)
    @orig_formatter.setStretch('log')

    #@orig_formatter.setColormap('standard')

    @original_display.draw(@orig_formatter.convert())

    @modelPadder = new Galactic.ImagePadder(image: image)

    @rows = @modelPadder.paddedImage.height
    @columns = @modelPadder.paddedImage.width

    @iModelImage = new Galactic.Image(width: @columns, height: @rows)

    @rRowModel = new Galactic.RowManipulator(image: @modelPadder.paddedImage)
    @iRowModel = new Galactic.RowManipulator(image: @iModelImage)
    @rColModel = new Galactic.ColumnManipulator(image: @modelPadder.paddedImage)
    @iColModel = new Galactic.ColumnManipulator(image: @iModelImage)

    @paddedLength = @rows*@columns
    @ldnRow = Math.log(@rows)/Math.LN2
    @ldnColumn = Math.log(@columns)/Math.LN2

    @padded_display = new Galactic.Display(container: 'padded', width: width, height: height)
    @padded_formatter = new Galactic.ImageFormatter(input: @modelPadder.paddedImage)
    @padded_formatter.setStretch('log')

    rows = @rows
    columns = @columns
    ldnRow = @ldnRow
    ldnCol = @ldnColumn

    modelData = image.data
    modelLength = image.width*image.height

    n = rows*columns
    norm = 1/n

    padder = @modelPadder
    paddedLength = rows*columns

    rModelData = @modelPadder.paddedImage.data
    iModelData = @iModelImage.data

    rRowM = @rRowModel
    iRowM = @iRowModel
    rColM = @rColModel
    iColM = @iColModel

    rRow = rRowM.row
    iRow = iRowM.row
    rCol = rColM.column
    iCol = iColM.column

    padder.load()
    @padded_formatter.min = Galactic.utils.arrayutils.min(@padded_formatter.input.data)
    @padded_formatter.max = Galactic.utils.arrayutils.max(@padded_formatter.input.data)
    @padded_display.draw(@padded_formatter.convert())

    l = paddedLength
    while l--
      iModelData[l] = 0

    fft_dif4_core = Galactic.math.fftdif4
    fft_dit4_core = Galactic.math.fftdit4

    r = rows
    while r--
      rRowM.load(r)
      iRowM.load(r)
      fft_dif4_core(iRow,rRow,ldnRow)
      rRowM.save(r)
      iRowM.save(r)

    c = columns
    while c--
      rColM.load(c)
      iColM.load(c)
      fft_dif4_core(iCol,rCol,ldnCol)
      rColM.save(c)
      iColM.save(c)

    @fft_formatter = new Galactic.ImageFormatter(input: @modelPadder.paddedImage)
    @fft_formatter.setStretch('log')
    @fft_formatter.min = Galactic.utils.arrayutils.min(@fft_formatter.input.data)
    @fft_formatter.max = Galactic.utils.arrayutils.max(@fft_formatter.input.data)
    @fft_display.draw(@fft_formatter.convert())

    r = rows
    while r--
      rRowM.load(r)
      iRowM.load(r)
      fft_dit4_core(rRow,iRow,ldnRow)
      rRowM.save(r)
      iRowM.save(r)

    c = columns
    while c--
      rColM.load(c)
      iColM.load(c)
      fft_dit4_core(rCol,iCol,ldnCol)
      rColM.save(c)
      iColM.save(c)

    @padded_inverse_display = new Galactic.Display(container: 'padded-inverse', width: width, height: height)
    @padded_inverse_formatter = new Galactic.ImageFormatter(input: @modelPadder.paddedImage)
    @padded_inverse_formatter.setStretch('log')
    @padded_inverse_formatter.min = Galactic.utils.arrayutils.min(@padded_inverse_formatter.input.data)
    @padded_inverse_formatter.max = Galactic.utils.arrayutils.max(@padded_inverse_formatter.input.data)
    @padded_inverse_display.draw(@padded_inverse_formatter.convert())

    padder.save()


    l = modelLength
    while l--
      modelData[l] *= norm

    @inverse_formatter = new Galactic.ImageFormatter(input: image)
    @inverse_formatter.setStretch('log')
    @inverse_formatter.min = Galactic.utils.arrayutils.min(@inverse_formatter.input.data)
    @inverse_formatter.max = Galactic.utils.arrayutils.max(@inverse_formatter.input.data)
    @inverse_display.draw(@inverse_formatter.convert())



  render: =>
    @html require('views/index')

module.exports = App
