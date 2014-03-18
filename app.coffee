window.App = Em.Application.create()

App.Router.map ->
	@route 'queue'
	@route 'about'
	@route 'preferences'

Em.TextField.reopen
	attributeBindings: ['nwdirectory']

App.ConfigKey = Em.Object.extend
	Name: ''
	DefaultValue: ''
	Value: ''

App.Config = Em.Object.extend
	keys: [
		App.ConfigKey.create
			Name: 'downloadPath'
			DefaultValue: ''
		App.ConfigKey.create
			Name: 'language'
			DefaultValue: 'en'
		App.ConfigKey.create
			Name: 'platform'
			DefaultValue: 'windows'
	]

	columns: [
		new Column 'Id', 'INTEGER', false, true, true
		new Column 'Key', 'TEXT', true, false, false, true
		new Column 'Value', 'TEXT'
	]

	getCreateTableSQL: ->
		columns = @get 'columns'
		len = columns.length
		columnsSQL = ''
		for column, i in columns
			columnsSQL += if len - 1 is i then column.getSQL() else column.getSQL() + ', '
		'CREATE TABLE IF NOT EXISTS `config` (' + columnsSQL + ')'

	insert: (database, createTable) ->
		columns = @get 'columns'
		colNames = ''
		len = columns.length
		for column, i in columns when column.Name isnt 'Id'
			colNames += if len-1 is i then '`' + column.Name + '`' else '`' + column.Name + '`, '
		keys = @get 'keys'
		database.transaction (tx) =>
			if createTable
				tx.executeSql @getCreateTableSQL()
			for key in keys
				value = if !!key.get 'Value' then key.get 'Value' else key.get 'DefaultValue'
				tx.executeSql 'INSERT INTO `config` (' + colNames + ') VALUES ("' + key.get('Name') + '", "' + value + '")'
	

	setValue: (key, value, db) ->
		db.transaction (tx) ->
			tx.executeSql 'UPDATE `config` SET `Value` = "' + value + '" WHERE `Key` = "' + key + '"'
		@get('keys').filterBy('Name', key)[0].set 'Value', value

	getLatestData: (db) ->
		that = this
		db.transaction (tx) =>
			tx.executeSql 'SELECT * FROM `config`', [], (tx, result) ->
				for row, i in result.rows
					that.get('keys')[i].set 'Value', result.rows.item(i).Value

	resetConfig: (db) ->
		db.transaction (tx) ->
			tx.executeSql 'DROP TABLE `config`'
			location.reload()

db = openDatabase 'app-db', '1.0', 'Cross platform YouTube downloader database.', 2 * 1024 * 1024

config = App.Config.create()
config.insert db, true

App.DirectoryChooser = Em.TextField.extend
	type: 'file'
	classNames: ['directory-chooser']
	change: (evt) ->
		config.get('keys').filterBy('Name', 'downloadPath')[0].set 'Value', evt.target.value

App.ChooseDirectoryButton = Em.View.extend
	tagName: 'span'
	classNames: ['btn', 'btn-blue']
	template: Em.Handlebars.compile 'Choose download directory'
	click: ->
		$('.directory-chooser').click()

App.PreferencesController = Em.Controller.extend
	model: config
	directory: (->
		downloadPath = @get('model.keys').filterBy('Name', 'downloadPath').get('firstObject').get 'Value'
		if !!downloadPath
			@get('model').setValue 'downloadPath', downloadPath, db
		@get('model').getLatestData db
		downloadPath
	).property 'model.keys.@each.Value'

App.PreferencesView = Em.View.extend
	controller: App.PreferencesController.create
		model: config

App.DropTable = Em.View.extend
	modalActive: false
	tagName: 'button'
	classNames: ['btn', 'btn-red']
	attributeBindings: ['disabled']
	disabled: false
	click: ->
		@set 'disabled', 'disabled'
		@set 'modalActive', true
	Modal: (->
		html = '<div title="Confirm action"><p>Are you sure you want to reset preferences?</p></div>'
		$(html).dialog
			height: 200
			modal: true
			buttons:
				Yes: ->
					config.resetConfig db
					$(this).dialog 'close'
				No: ->
					$(this).dialog 'close'
	).property 'modalActive'